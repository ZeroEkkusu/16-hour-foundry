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
import {Auth, Authority} from "solmate/auth/Auth.sol";

/// @title Defiant
/// @notice Short assets with ETH and earn passive income
contract Defiant is Auth {
    error InsufficientFunds(uint256 amount, uint256 maxAmount);
    event Updated(
        address _wethGatewayAddr,
        address _lendingPoolAddressesProviderAddr,
        address _lendingPoolAddr,
        address _protocolDataProviderAddr,
        address _priceOracleAddr,
        address _wethAddr,
        address _aWethAddr,
        uint256 _lendingPoolWethAllowance,
        address _swapRouterAddr
    );

    IWETHGateway internal wethGateway;
    ILendingPoolAddressesProvider internal lendingPoolAddressesProvider;
    ILendingPool internal lendingPool;
    IProtocolDataProvider internal protocolDataProvider;
    IPriceOracle internal priceOracle;

    ERC20 internal weth;
    ERC20 internal aWeth;

    ISwapRouter internal swapRouter;

    /// @dev Passing every value manually would be cheaper;
    /// @dev for the sake of learning, we'll let the constructor
    /// @dev fetch some values automatically
    /// @dev
    /// @dev Do not send money to the constructor
    /// @dev Optimized for lower deployment cost
    constructor(
        address wethGatewayAddr,
        address lendingPoolAddressesProviderAddr,
        address protocolDataProviderAddr,
        address swapRouterAddr,
        address _authorityAddr
    ) payable Auth(msg.sender, Authority(_authorityAddr)) {
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

        // We need to approve the lending pool to use our WETH
        SafeTransferLib.safeApprove(weth, address(lendingPool), 2**256 - 1);

        swapRouter = ISwapRouter(swapRouterAddr);
    }

    /// @notice Start earning passive income with ETH
    function startEarning() public payable {
        wethGateway.depositETH{value: msg.value}(
            address(lendingPool),
            msg.sender,
            0
        );
    }

    /// @notice Start earning passive income with WETH
    /// @dev The calling address must approve this contract to spend
    /// @dev at least `amount` worth of its WETH to be able to deposit it
    function startEarningWrapped(uint256 amount) public {
        uint256 wethBalance = weth.balanceOf(msg.sender);
        if (amount > wethBalance) revert InsufficientFunds(amount, wethBalance);

        SafeTransferLib.safeTransferFrom(
            weth,
            msg.sender,
            address(this),
            amount
        );

        lendingPool.deposit(address(weth), amount, msg.sender, 0);
    }

    /// @notice Pass an amount in ETH to calculate the amount of an asset
    function calculateAmount_tb_(uint256 ethAmount, address assetAddr)
        public
        view
        returns (uint256, uint256)
    {
        uint256 assetPrice = priceOracle.getAssetPrice(assetAddr);
        // Correct the number of decimal places to 18 if the asset
        // has less than 18 decimal places
        uint256 decimalsToAdd = 18 - ERC20(assetAddr).decimals();
        return (
            (ethAmount * 1e18) / (assetPrice * 10**decimalsToAdd),
            assetPrice * 10**decimalsToAdd
        );
    }

    /// @notice Open a short position
    /// @dev The calling address must approve this contract to borrow
    /// @dev at least `ethAmount / assetPrice` worth of the asset
    /// @dev to be able to open a short
    function openShort____1l(
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

        // Defiant uses only aWETH for borrowing
        if (!wethUsageAsCollateralEnabled) {
            revert InsufficientFunds(ethAmount, 0);
        }

        // Revert if `msg.sender` does not have enough aWETH
        // or borrowing power
        uint256 aWethBalance = aWeth.balanceOf(msg.sender);
        if (ethAmount > availableBorrowsETH) {
            revert InsufficientFunds(
                ethAmount,
                availableBorrowsETH >= aWethBalance
                    ? aWethBalance
                    : availableBorrowsETH
            );
        }

        (uint256 assetAmount, uint256 assetPrice) = calculateAmount_tb_(
            ethAmount,
            assetAddr
        );

        // Borrow the asset
        lendingPool.borrow(
            assetAddr,
            assetAmount,
            interestRateMode,
            0,
            msg.sender
        );

        // Sell the asset for WETH
        uint256 _ethAmount = swapExactInputSingle(
            assetAddr,
            assetAmount,
            wethAddr,
            // Allow max slippage 2%
            (assetAmount * assetPrice * 9800) / 1e22,
            uniswapPoolFee
        );

        // Continue earning passive income on WETH
        lendingPool.deposit(wethAddr, _ethAmount, msg.sender, 0);
    }

    /// @notice Close a short position
    /// @notice Pass a bit higher `ethAmount` when closing an entire position
    /// @dev The calling address must approve this contract to spend
    /// @dev at least `ethAmount` worth of its aWETH to be able to close a short
    function closeShort___h6U(
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
        (, , uint256 availableBorrowsETH, , , ) = lendingPool
            .getUserAccountData(msg.sender);

        // Revert if `msg.sender` does not have enough aWETH
        // or borrowing power (to withdraw `ethAmount`)
        if (
            ethAmount > aWethBalance ||
            (wethUsageAsCollateralEnabled && ethAmount > availableBorrowsETH)
        ) {
            revert InsufficientFunds(
                ethAmount,
                !wethUsageAsCollateralEnabled
                    ? aWethBalance
                    : (
                        availableBorrowsETH >= aWethBalance
                            ? aWethBalance
                            : availableBorrowsETH
                    )
            );
        }

        // We need to transfer aWETH to this contract to withdraw it
        SafeTransferLib.safeTransferFrom(
            _aWeth,
            msg.sender,
            address(this),
            ethAmount
        );

        lendingPool.withdraw(wethAddr, ethAmount, address(this));

        (uint256 assetAmount, ) = calculateAmount_tb_(ethAmount, assetAddr);

        // Sell WETH for the asset
        uint256 _assetAmount = swapExactInputSingle(
            wethAddr,
            ethAmount,
            assetAddr,
            // Allow max slippage 2%
            (assetAmount * 9800) / 1e22,
            uniswapPoolFee
        );

        // We need to approve the lending pool to use our asset
        SafeTransferLib.safeApprove(
            ERC20(assetAddr),
            address(lendingPool),
            _assetAmount
        );

        // Repay debt
        lendingPool.repay(
            assetAddr,
            _assetAmount,
            interestRateMode,
            msg.sender
        );

        // If there is any remainder after repaying,
        // start earning passive income on it
        lendingPool.deposit(
            assetAddr,
            ERC20(assetAddr).balanceOf(address(this)),
            msg.sender,
            0
        );
    }

    /// @notice Uniswap: swap an amount of `_tokenIn` for the max amount of `_tokenOut`
    /// @dev The calling address must approve this contract to spend
    /// @dev at least `_amountIn` worth of its `_tokenIn` for this function to succeed
    function swapExactInputSingle(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        uint256 _amountOutMinimum,
        uint24 _fee
    ) internal returns (uint256 amountOut) {
        // We need to approve the swap router to use our `_tokenIn`
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

    function update_Xx(
        address _wethGatewayAddr,
        address _lendingPoolAddressesProviderAddr,
        address _lendingPoolAddr,
        address _protocolDataProviderAddr,
        address _priceOracleAddr,
        address _wethAddr,
        address _aWethAddr,
        uint256 _lendingPoolWethAllowance,
        address _swapRouterAddr
    ) public requiresAuth {
        wethGateway = IWETHGateway(_wethGatewayAddr);
        lendingPoolAddressesProvider = ILendingPoolAddressesProvider(
            _lendingPoolAddressesProviderAddr
        );
        lendingPool = ILendingPool(_lendingPoolAddr);
        protocolDataProvider = IProtocolDataProvider(_protocolDataProviderAddr);
        priceOracle = IPriceOracle(_priceOracleAddr);

        weth = ERC20(_wethAddr);
        aWeth = ERC20(_aWethAddr);

        SafeTransferLib.safeApprove(
            weth,
            _lendingPoolAddr,
            _lendingPoolWethAllowance
        );

        swapRouter = ISwapRouter(_swapRouterAddr);

        emit Updated(
            _wethGatewayAddr,
            _lendingPoolAddressesProviderAddr,
            _lendingPoolAddr,
            _protocolDataProviderAddr,
            _priceOracleAddr,
            _wethAddr,
            _aWethAddr,
            _lendingPoolWethAllowance,
            _swapRouterAddr
        );
    }
}
