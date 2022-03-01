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
    /// @dev to be able to open a short
    function openShort(
        uint256 ethAmount,
        address assetAddr,
        uint256 interestRateMode,
        uint24 uniswapPoolFee,
        bool custodyFunds
    ) public {
        address wethAddr = address(weth);
        (, , uint256 availableBorrowsETH, , , ) = lendingPool
            .getUserAccountData(msg.sender);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            bool wethUsageAsCollateralEnabled
        ) = protocolDataProvider.getUserReserveData(wethAddr, msg.sender);
        // Defiant uses only aWETH!
        if (!wethUsageAsCollateralEnabled) {
            revert InsufficientFunds(ethAmount, 0);
        }
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
            wethAddr,
            (amount * assetPrice * 0.99e18) / 1e36,
            uniswapPoolFee
        );

        if (custodyFunds) {
            unchecked {
                addressToCustodiedFunds[msg.sender] += _ethAmount;
            }
        } else {
            lendingPool.deposit(wethAddr, _ethAmount, msg.sender, 0);
        }
    }

    /// @notice Send `ethAmount` slightly higher than the current shorted amount to close entirely
    /// @dev The calling address must approve this contract to spend
    /// @dev at least `ethAmount` worth of its aWETH to be able to close a short
    function closeShort(
        uint256 ethAmount,
        address assetAddr,
        uint256 interestRateMode,
        uint24 uniswapPoolFee
    ) public {
        uint256 custodiedFunds = addressToCustodiedFunds[msg.sender];

        address wethAddr = address(weth);
        (address aWethAddr, , ) = protocolDataProvider
            .getReserveTokensAddresses(wethAddr); // this vs sload
        uint256 aWethBalance = ERC20(aWethAddr).balanceOf(msg.sender);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            bool wethUsageAsCollateralEnabled
        ) = protocolDataProvider.getUserReserveData(wethAddr, msg.sender);
        // Defiant uses only aWETH!
        if (!wethUsageAsCollateralEnabled) {
            revert InsufficientFunds(ethAmount, 0);
        }
        // `ethAmount` cannot be greater than how much `msg.sender`'s aWeth balance!
        if (ethAmount > custodiedFunds + aWethBalance) {
            revert InsufficientFunds(ethAmount, custodiedFunds + aWethBalance);
        }

        // TODO Flashloan case

        uint256 aWethAmount = ethAmount - custodiedFunds;
        SafeTransferLib.safeTransferFrom(
            ERC20(aWethAddr),
            msg.sender,
            address(this),
            aWethAmount
        );

        lendingPool.withdraw(wethAddr, aWethAmount, address(this));

        (uint256 assetAmount, ) = calculateAmount(ethAmount, assetAddr);

        uint256 _assetAmount = swapExactInputSingle(
            wethAddr,
            ethAmount,
            assetAddr,
            (assetAmount * 0.99e18) / 1e36,
            uniswapPoolFee
        );

        SafeTransferLib.safeApprove(
            ERC20(assetAddr),
            address(lendingPool),
            _assetAmount
        );

        lendingPool.repay(
            assetAddr,
            _assetAmount,
            interestRateMode,
            msg.sender
        );
    }

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
        TODO Must include updated allowances
    }*/
}
