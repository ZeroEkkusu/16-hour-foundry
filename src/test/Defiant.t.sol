// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {ILendingPoolAddressesProvider} from "src/interfaces/ILendingPoolAddressesProvider.sol";
import {IProtocolDataProvider} from "src/interfaces/IProtocolDataProvider.sol";
import {IDebtToken} from "src/interfaces/IDebtToken.sol";
import {Defiant} from "src/Defiant.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {DSTest} from "ds-test/test.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {Vm} from "forge-std/Vm.sol";
import {AddressBook} from "src/test/utils/AddressBook.sol";

contract DefiantUnitTest is DSTest, stdCheats, AddressBook {
    ERC20 weth;
    ERC20 aWeth;
    ERC20 asset;
    IDebtToken sdAsset;
    IDebtToken vdAsset;
    ILendingPoolAddressesProvider lendingPoolAddressProvider;
    IProtocolDataProvider protocolDataProvider;

    Defiant defiant;
    uint256 wethAmount;

    Vm vm = Vm(HEVM_ADDRESS);

    constructor() {
        weth = ERC20(WETH_ADDRESS);
        // You can customize which asset to short
        asset = ERC20(DAI_ADDRESS);
        lendingPoolAddressProvider = ILendingPoolAddressesProvider(
            LENDING_POOL_ADDRESS_PROVIDER_ADDRESS
        );
        protocolDataProvider = IProtocolDataProvider(
            PROTOCOL_DATA_PROVIDER_ADDRESS
        );
        (address aWethAddr, , ) = protocolDataProvider
            .getReserveTokensAddresses(WETH_ADDRESS);
        (, address sdAssetAddr, address vdAssetAddr) = protocolDataProvider
            .getReserveTokensAddresses(address(asset));
        aWeth = ERC20(aWethAddr);
        sdAsset = IDebtToken(sdAssetAddr);
        vdAsset = IDebtToken(vdAssetAddr);
    }

    function setUp() public {
        // You can customize the minimum amount of WETH to transfer to this contract
        wethAmount = 1 ether;

        defiant = new Defiant(
            WETH_GATEWAY_ADDRESS,
            LENDING_POOL_ADDRESS_PROVIDER_ADDRESS,
            PROTOCOL_DATA_PROVIDER_ADDRESS,
            SWAP_ROUTER_ADDRESS
        );
        tip(WETH_ADDRESS, address(this), wethAmount);
        weth.approve(address(defiant), 2**256 - 1);
        aWeth.approve(address(defiant), 2**256 - 1);
        sdAsset.approveDelegation(address(defiant), 2**256 - 1);
        vdAsset.approveDelegation(address(defiant), 2**256 - 1);
    }

    function testStartEarning() public {
        defiant.startEarning{value: wethAmount}();
        assertEq(aWeth.balanceOf(address(this)), wethAmount);
    }

    function testStartEarningWrapped() public {
        defiant.startEarningWrapped(wethAmount);
        assertEq(aWeth.balanceOf(address(this)), wethAmount);
    }

    function testCannotStartEarningWrappedInsufficientFunds() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Defiant.InsufficientFunds.selector,
                wethAmount * 2,
                wethAmount
            )
        );
        defiant.startEarningWrapped(wethAmount * 2);
    }

    function testOpenShort() public {
        defiant.startEarningWrapped(wethAmount);
        // You can customize the interest rate mode to use (stable: 1, variable: 2)
        uint256 interestRateMode = 1;
        // You can customize the uniswap pool fee
        uint24 uniswapPoolFee = 3000;
        // You can customize whether or not to deposit WETH in the lending pool after opening a short
        bool custodyFunds = false;
        IDebtToken dAsset = interestRateMode == 1 ? sdAsset : vdAsset;
        uint256 amountInWethToShort = wethAmount / 10;
        uint256 prevBalance = weth.balanceOf(address(this));

        defiant.openShort(
            amountInWethToShort,
            address(asset),
            interestRateMode,
            uniswapPoolFee,
            custodyFunds
        );
        (uint256 amount, ) = defiant.calculateAmount(
            amountInWethToShort,
            address(asset)
        );
        assertEq(dAsset.balanceOf(address(this)), amount);
        if (custodyFunds) {
            assertGe(
                defiant.addressToCustodiedFunds(address(this)),
                (amountInWethToShort * 0.989e18) / 1e18
            );
        } else {
            assertGe(
                weth.balanceOf(address(this)),
                (prevBalance * 0.989e18) / 1e18
            );
        }
    }

    function testCannotOpenShortInsufficientFunds() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Defiant.InsufficientFunds.selector,
                wethAmount,
                0
            )
        );
        defiant.openShort(wethAmount, address(asset), 1, 3000, true);
    }

    function testCloseShort() public {
        defiant.startEarningWrapped(wethAmount);
        // You can customize the interest rate mode to use (stable: 1, variable: 2)
        uint256 interestRateMode = 1;
        // You can customize the uniswap pool fee
        uint24 uniswapPoolFee = 3000;
        // You can customize whether or not to deposit WETH in the lending pool after opening a short
        bool custodyFunds = false;
        IDebtToken dAsset = interestRateMode == 1 ? sdAsset : vdAsset;
        uint256 amountInWethToShort = wethAmount / 10;
        uint256 prevBalance = weth.balanceOf(address(this));
        defiant.openShort(
            amountInWethToShort,
            address(asset),
            interestRateMode,
            uniswapPoolFee,
            custodyFunds
        );
        (, uint256 assetPrice) = defiant.calculateAmount(0, address(asset));
        uint256 dAmount = dAsset.balanceOf(address(this));

        defiant.closeShort(
            ((dAmount * assetPrice) * 1.01e18) / 1e36,
            address(asset),
            interestRateMode,
            uniswapPoolFee
        );
        assertEq(dAsset.balanceOf(address(this)), 0);
    }
}
