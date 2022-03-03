// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {IProtocolDataProvider} from "src/interfaces/IProtocolDataProvider.sol";
import {IDebtToken} from "src/interfaces/IDebtToken.sol";
import {Defiant} from "src/Defiant.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {DSTest} from "ds-test/test.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {Vm} from "forge-std/Vm.sol";
import {AuthorityDeployer} from "src/test/utils/AuthorityDeployer.sol";
import {AddressBook} from "src/test/utils/AddressBook.sol";

contract DefiantUnitTest is DSTest, stdCheats, AuthorityDeployer, AddressBook {
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

    ERC20 weth;
    ERC20 aWeth;
    ERC20 asset;
    IDebtToken sdAsset;
    IDebtToken vdAsset;
    IProtocolDataProvider protocolDataProvider;

    Defiant defiant;
    uint256 wethAmount;

    Vm vm = Vm(HEVM_ADDRESS);

    constructor() {
        weth = ERC20(WETH_ADDRESS);
        // You can customize which asset to short
        asset = ERC20(DAI_ADDRESS);
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
            SWAP_ROUTER_ADDRESS,
            AUTHORITY_ADDRESS
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
        IDebtToken dAsset = interestRateMode == 1 ? sdAsset : vdAsset;
        uint256 amountInWethToShort = wethAmount / 10;
        uint256 prevBalance = aWeth.balanceOf(address(this));

        defiant.openShort(
            amountInWethToShort,
            address(asset),
            interestRateMode,
            uniswapPoolFee
        );
        (uint256 amount, ) = defiant.calculateAmount(
            amountInWethToShort,
            address(asset)
        );
        assertEq(dAsset.balanceOf(address(this)), amount);
        assertGe(aWeth.balanceOf(address(this)), (prevBalance * 9900) / 1e4);
    }

    function testCannotOpenShortInsufficientFunds() public {
        defiant.startEarningWrapped(wethAmount - 1);
        (, uint256 ltv, , , , , , , , ) = protocolDataProvider
            .getReserveConfigurationData(address(weth));

        vm.expectRevert(
            abi.encodeWithSelector(
                Defiant.InsufficientFunds.selector,
                wethAmount,
                ((wethAmount - 1) * ltv) / 1e4
            )
        );
        defiant.openShort(wethAmount, address(asset), 1, 3000);
    }

    function testCloseShort() public {
        defiant.startEarningWrapped(wethAmount);
        // You can customize the interest rate mode to use (stable: 1, variable: 2)
        uint256 interestRateMode = 1;
        // You can customize the uniswap pool fee
        uint24 uniswapPoolFee = 3000;
        IDebtToken dAsset = interestRateMode == 1 ? sdAsset : vdAsset;
        uint256 amountInWethToShort = wethAmount / 10;
        defiant.openShort(
            amountInWethToShort,
            address(asset),
            interestRateMode,
            uniswapPoolFee
        );
        (, uint256 assetPrice) = defiant.calculateAmount(0, address(asset));
        uint256 dAmount = dAsset.balanceOf(address(this));

        defiant.closeShort(
            ((dAmount * assetPrice) * 1010) / 1e21,
            address(asset),
            interestRateMode,
            uniswapPoolFee
        );
        assertEq(dAsset.balanceOf(address(this)), 0);
    }

    function testCannotCloseShortInsufficientFunds() public {
        defiant.startEarningWrapped(wethAmount - 1);
        (, uint256 ltv, , , , , , , , ) = protocolDataProvider
            .getReserveConfigurationData(address(weth));

        vm.expectRevert(
            abi.encodeWithSelector(
                Defiant.InsufficientFunds.selector,
                wethAmount,
                ((wethAmount - 1) * ltv) / 1e4
            )
        );
        defiant.closeShort(wethAmount, address(asset), 1, 3000);
    }

    function testUpdate() public {
        address newWethGatewayAddr = address(999);
        address newLendingPoolAddressesProviderAddr = address(888);
        address newLendingPoolAddr = address(777);
        address newProtocolDataProviderAddr = address(666);
        address newPriceOracleAddr = address(555);
        address newWethAddr = address(444);
        address newAWethAddr = address(333);
        uint256 newLendingPoolWethAllowance = 0;
        address newSwapRouterAddr = address(222);

        vm.expectEmit(false, false, false, true);
        emit Updated(
            newWethGatewayAddr,
            newLendingPoolAddressesProviderAddr,
            newLendingPoolAddr,
            newProtocolDataProviderAddr,
            newPriceOracleAddr,
            newWethAddr,
            newAWethAddr,
            newLendingPoolWethAllowance,
            newSwapRouterAddr
        );
        defiant.update(
            newWethGatewayAddr,
            newLendingPoolAddressesProviderAddr,
            newLendingPoolAddr,
            newProtocolDataProviderAddr,
            newPriceOracleAddr,
            newWethAddr,
            newAWethAddr,
            newLendingPoolWethAllowance,
            newSwapRouterAddr
        );
        assertEq(
            address(
                uint160(uint256(vm.load(address(defiant), bytes32(uint256(2)))))
            ),
            newWethGatewayAddr
        );
        assertEq(
            address(
                uint160(uint256(vm.load(address(defiant), bytes32(uint256(3)))))
            ),
            newLendingPoolAddressesProviderAddr
        );
        assertEq(
            address(
                uint160(uint256(vm.load(address(defiant), bytes32(uint256(4)))))
            ),
            newLendingPoolAddr
        );
        assertEq(
            address(
                uint160(uint256(vm.load(address(defiant), bytes32(uint256(5)))))
            ),
            newProtocolDataProviderAddr
        );
        assertEq(
            address(
                uint160(uint256(vm.load(address(defiant), bytes32(uint256(6)))))
            ),
            newPriceOracleAddr
        );
        assertEq(
            address(
                uint160(uint256(vm.load(address(defiant), bytes32(uint256(7)))))
            ),
            newWethAddr
        );
        assertEq(
            address(
                uint160(uint256(vm.load(address(defiant), bytes32(uint256(8)))))
            ),
            newAWethAddr
        );
        assertEq(
            weth.allowance(address(defiant), address(LENDING_POOL_ADDRESS)),
            newLendingPoolWethAllowance
        );
        assertEq(
            address(
                uint160(uint256(vm.load(address(defiant), bytes32(uint256(9)))))
            ),
            newSwapRouterAddr
        );
    }

    function testCannotUpdateUnauthorized() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        defiant.update(
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            0,
            address(0)
        );
    }
}
