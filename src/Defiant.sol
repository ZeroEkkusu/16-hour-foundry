// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {IWETHGateway} from "src/interfaces/IWETHGateway.sol";
import {ILendingPoolAddressesProvider} from "src/interfaces/ILendingPoolAddressesProvider.sol";
import {ILendingPool} from "src/interfaces/ILendingPool.sol";
import {IProtocolDataProvider} from "src/interfaces/IProtocolDataProvider.sol";
import {IPriceOracle} from "src/interfaces/IPriceOracle.sol";
import {ISwapRouter} from "src/interfaces/ISwapRouter.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice Short assets with ETH and earn passive income
contract Defiant {
    error InsufficientFunds(uint256 amount, uint256 maxAmount);

    IWETHGateway internal wethGateway;
    ILendingPoolAddressesProvider internal lendingPoolAddressProvider;
    ILendingPool internal lendingPool;
    IProtocolDataProvider internal protocolDataProvider;
    IPriceOracle internal priceOracle;

    ERC20 weth;

    ISwapRouter internal swapRouter;

    mapping(address => uint256) public addressToCustodiedFunds;

    constructor(
        address wethGatewayAddr,
        address lendingPoolAddressProviderAddr,
        address protocolDataProviderAddr,
        address swapRouterAddr
    ) payable {
        wethGateway = IWETHGateway(wethGatewayAddr);
        lendingPoolAddressProvider = ILendingPoolAddressesProvider(
            lendingPoolAddressProviderAddr
        );
        lendingPool = ILendingPool(lendingPoolAddressProvider.getLendingPool());
        protocolDataProvider = IProtocolDataProvider(protocolDataProviderAddr);
        priceOracle = IPriceOracle(lendingPoolAddressProvider.getPriceOracle());

        weth = ERC20(wethGateway.getWETHAddress());

        SafeTransferLib.safeApprove(weth, address(lendingPool), 2**256 - 1);

        swapRouter = ISwapRouter(swapRouterAddr);
    }

    function startEarning() public payable {
        wethGateway.depositETH{value: msg.value}(
            address(lendingPool),
            msg.sender,
            0
        );
    }

    /// @dev The calling address must approve this contract to spend
    /// @dev at least `amount` worth of its WETH to be able to deposit WETH
    function startEarningWrapped(uint256 amount) public {
        uint256 wethBalance = weth.balanceOf(msg.sender);
        if (wethBalance < amount) revert InsufficientFunds(amount, wethBalance);

        SafeTransferLib.safeTransferFrom(
            weth,
            msg.sender,
            address(this),
            amount
        );

        lendingPool.deposit(address(weth), amount, msg.sender, 0);
    }

    function calculateAmount(uint256 ethAmount, address assetAddr)
        public
        view
        returns (uint256, uint256)
    {
        uint256 assetPrice = priceOracle.getAssetPrice(assetAddr);
        return ((ethAmount * 1e18) / assetPrice, assetPrice);
    }

    /// @dev The calling address must approve this contract to borrow
    /// @dev at least `ethAmount / asset price in ETH` worth of the asset
    /// @dev to be able to borrow it
    function openShort(
        uint256 ethAmount,
        address assetAddr,
        uint256 interestRateMode,
        uint24 uniswapPoolFee,
        bool continueEarning
    ) public {
        address wethAddress = address(weth);
        (, , uint256 availableBorrowsETH, , , ) = lendingPool
            .getUserAccountData(msg.sender);
        if (ethAmount > availableBorrowsETH)
            revert InsufficientFunds(ethAmount, availableBorrowsETH);

        (uint256 amount, uint256 assetPrice) = calculateAmount(
            ethAmount,
            assetAddr
        );

        lendingPool.borrow(assetAddr, amount, interestRateMode, 0, msg.sender);

        uint256 _ethAmount = swapExactInputSingle(
            assetAddr,
            amount,
            wethAddress,
            (amount * assetPrice * 0.99e18) / 1e36,
            uniswapPoolFee
        );

        if (continueEarning) {
            lendingPool.deposit(wethAddress, _ethAmount, msg.sender, 0);
        } else {
            unchecked {
                addressToCustodiedFunds[msg.sender] += _ethAmount;
            }
        }
    }

    /*function closeShort(
        uint256 ethAmount,
        address assetAddr,
        uint256 interestRateMode,
        uint24 uniswapPoolFee
    ) {}*/

    /// @dev The calling address must approve this contract to spend
    /// @dev at least `_amountIn` worth of its `_tokenIn` for this function to succeed
    function swapExactInputSingle(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        uint256 _amountOutMinimum,
        uint24 _fee
    ) internal returns (uint256 amountOut) {
        SafeTransferLib.safeApprove(
            ERC20(_tokenIn),
            address(swapRouter),
            _amountIn
        );

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: _fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);
    }

    /*function update(address wethGatewayAddr, address swapRouterAddr) public {
        wethGateway = IWETHGateway(wethGatewayAddr);
        swapRouter = ISwapRouter(swapRouterAddr);
    }*/
}
