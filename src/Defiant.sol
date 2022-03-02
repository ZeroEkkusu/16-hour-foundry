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
    ILendingPoolAddressesProvider internal lendingPoolAddressesProvider;
    ILendingPool internal lendingPool;
    IProtocolDataProvider internal protocolDataProvider;
    IPriceOracle internal priceOracle;

    ERC20 weth;
    ERC20 aWeth;

    ISwapRouter internal swapRouter;

    /// @dev Passing everything manually would be cheaper, but for the sake of learning
    /// @dev we'll let our constructor fetch some addresses automatically
    constructor(
        address wethGatewayAddr,
        address lendingPoolAddressesProviderAddr,
        address protocolDataProviderAddr,
        address swapRouterAddr
    ) payable {
        wethGateway = IWETHGateway(wethGatewayAddr);
        lendingPoolAddressesProvider = ILendingPoolAddressesProvider(
            lendingPoolAddressesProviderAddr
        );
        lendingPool = ILendingPool(
            lendingPoolAddressesProvider.getLendingPool()
        );
        protocolDataProvider = IProtocolDataProvider(protocolDataProviderAddr);
        priceOracle = IPriceOracle(
            lendingPoolAddressesProvider.getPriceOracle()
        );

        weth = ERC20(wethGateway.getWETHAddress());
        (address aWethAddr, , ) = protocolDataProvider
            .getReserveTokensAddresses(address(weth));
        aWeth = ERC20(aWethAddr);

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
        uint24 uniswapPoolFee
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

        uint256 aWethBalance = aWeth.balanceOf(msg.sender);
        if (ethAmount > availableBorrowsETH) {
            revert InsufficientFunds(
                ethAmount,
                availableBorrowsETH >= aWethBalance
                    ? aWethBalance
                    : availableBorrowsETH
            );
        }

        (uint256 amount, uint256 assetPrice) = calculateAmount(
            ethAmount,
            assetAddr
        );

        lendingPool.borrow(assetAddr, amount, interestRateMode, 0, msg.sender);

        uint256 _ethAmount = swapExactInputSingle(
            assetAddr,
            amount,
            wethAddr,
            (amount * assetPrice * 9900) / 1e22,
            uniswapPoolFee
        );

        lendingPool.deposit(wethAddr, _ethAmount, msg.sender, 0);
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
        address wethAddr = address(weth);
        ERC20 _aWeth = aWeth;
        uint256 aWethBalance = _aWeth.balanceOf(msg.sender);

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
        // `ethAmount` cannot be greater than `msg.sender`'s aWeth balance!
        if (ethAmount > aWethBalance) {
            revert InsufficientFunds(ethAmount, aWethBalance);
        }

        // TODO Flashloan case

        SafeTransferLib.safeTransferFrom(
            _aWeth,
            msg.sender,
            address(this),
            ethAmount
        );

        lendingPool.withdraw(wethAddr, ethAmount, address(this));

        (uint256 assetAmount, ) = calculateAmount(ethAmount, assetAddr);

        uint256 _assetAmount = swapExactInputSingle(
            wethAddr,
            ethAmount,
            assetAddr,
            (assetAmount * 9900) / 1e22,
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

        lendingPool.deposit(
            assetAddr,
            ERC20(assetAddr).balanceOf(address(this)),
            msg.sender,
            0
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
