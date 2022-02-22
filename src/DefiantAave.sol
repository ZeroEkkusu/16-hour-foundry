// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {IWETHGateway} from "src/interfaces/IWETHGateway.sol";
import {ILendingPoolAddressesProvider} from "src/interfaces/ILendingPoolAddressesProvider.sol";
import {ILendingPool} from "src/interfaces/ILendingPool.sol";
import {IProtocolDataProvider} from "src/interfaces/IProtocolDataProvider.sol";
import {ISwapRouter} from "src/interfaces/ISwapRouter.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract DefiantAave {
    IWETHGateway internal wethGateway;
    ILendingPoolAddressesProvider internal lendingPoolAddressProvider;
    ILendingPool internal lendingPool;
    IProtocolDataProvider internal protocolDataProvider;

    ISwapRouter internal swapRouter;

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

        swapRouter = ISwapRouter(swapRouterAddr);
    }

    function startEarning() public payable {
        wethGateway.depositETH{value: msg.value}(
            address(lendingPool),
            msg.sender,
            0
        );
    }

    function openShort(address tokenAddr) public {
        //lendingPool.borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf);
    }

    function closeShort(address tokenAddr) public {}

    /// @dev The calling address must approve this contract
    /// @dev to spend at least `_amountIn` worth of its `_tokenIn` for this function to succeed
    function swapExactInputSingle(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        uint24 _fee
    ) external returns (uint256 amountOut) {
        SafeTransferLib.safeTransferFrom(
            ERC20(_tokenIn),
            msg.sender,
            address(this),
            _amountIn
        );

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
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: 0, // TODO
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);
    }

    function update(address wethGatewayAddr, address swapRouterAddr) public {
        wethGateway = IWETHGateway(wethGatewayAddr);
        swapRouter = ISwapRouter(swapRouterAddr);
    }
}
