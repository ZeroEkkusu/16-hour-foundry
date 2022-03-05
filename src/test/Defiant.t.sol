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
    // You can customize the amount of WETH to fund this contract with
    uint256 constant SOME_WETH_AMOUNT = 1 ether;
    // You can choose the uniswap pool fee
    uint24 constant UNISWAP_POOL_FEE = 3000;

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
    ERC20 aAsset;
    IDebtToken sdAsset;
    IDebtToken vdAsset;
    IProtocolDataProvider protocolDataProvider;

    Defiant defiant;

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
        (
            address aAssetAddr,
            address sdAssetAddr,
            address vdAssetAddr
        ) = protocolDataProvider.getReserveTokensAddresses(address(asset));
        aWeth = ERC20(aWethAddr);
        aAsset = ERC20(aAssetAddr);
        sdAsset = IDebtToken(sdAssetAddr);
        vdAsset = IDebtToken(vdAssetAddr);
    }

    function setUp() public {
        defiant = new Defiant(
            WETH_GATEWAY_ADDRESS,
            LENDING_POOL_ADDRESS_PROVIDER_ADDRESS,
            PROTOCOL_DATA_PROVIDER_ADDRESS,
            SWAP_ROUTER_ADDRESS,
            AUTHORITY_ADDRESS
        );
        tip(WETH_ADDRESS, address(this), SOME_WETH_AMOUNT);
        weth.approve(address(defiant), 2**256 - 1);
        aWeth.approve(address(defiant), 2**256 - 1);
        sdAsset.approveDelegation(address(defiant), 2**256 - 1);
        vdAsset.approveDelegation(address(defiant), 2**256 - 1);
    }

    function testStartEarning() public {
        defiant.startEarning{value: SOME_WETH_AMOUNT}();
        assertGe(aWeth.balanceOf(address(this)), SOME_WETH_AMOUNT);
    }

    function testStartEarningWrapped() public {
        defiant.startEarningWrapped(SOME_WETH_AMOUNT);
        assertGe(aWeth.balanceOf(address(this)), SOME_WETH_AMOUNT);
    }

    function testCannotStartEarningWrappedInsufficientFunds() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Defiant.InsufficientFunds.selector,
                SOME_WETH_AMOUNT * 2,
                SOME_WETH_AMOUNT
            )
        );
        defiant.startEarningWrapped(SOME_WETH_AMOUNT * 2);
    }

    function testOpenShort() public {
        defiant.startEarningWrapped(SOME_WETH_AMOUNT);
        // You can customize the interest rate mode to use (stable: 1, variable: 2)
        uint256 interestRateMode = 1;
        // You can customize the amount in WETH to short
        uint256 amountInWethToShort = SOME_WETH_AMOUNT / 10;
        IDebtToken dAsset = interestRateMode == 1 ? sdAsset : vdAsset;
        uint256 prevBalance = aWeth.balanceOf(address(this));

        defiant.openShort____1l(
            amountInWethToShort,
            address(asset),
            interestRateMode,
            UNISWAP_POOL_FEE
        );
        (uint256 assetAmount, ) = defiant.calculateAmount_tb_(
            amountInWethToShort,
            address(asset)
        );
        assertGe(dAsset.balanceOf(address(this)), assetAmount);
        assertGe(aWeth.balanceOf(address(this)), (prevBalance * 9800) / 1e4);
    }

    function testCannotOpenShortInsufficientFunds() public {
        defiant.startEarningWrapped(SOME_WETH_AMOUNT - 1);
        (, uint256 ltv, , , , , , , , ) = protocolDataProvider
            .getReserveConfigurationData(address(weth));
        // Deposit LINK to ensure only aWETH is considered when assesing borrowing power
        tip(LINK_ADDRESS, address(this), 1000e18);
        (bool sent, ) = LENDING_POOL_ADDRESS.call(
            abi.encodeWithSelector(
                0xe8eda9df,
                LINK_ADDRESS,
                1000e18,
                address(this),
                0
            )
        );
        require(sent);

        vm.expectRevert(
            abi.encodeWithSelector(
                Defiant.InsufficientFunds.selector,
                SOME_WETH_AMOUNT,
                ((SOME_WETH_AMOUNT - 1) * ltv) / 1e4
            )
        );
        defiant.openShort____1l(SOME_WETH_AMOUNT, address(asset), 1, 3000);
    }

    function testCloseShort() public {
        defiant.startEarningWrapped(SOME_WETH_AMOUNT);
        // You can customize the interest rate mode to use (stable: 1, variable: 2)
        uint256 interestRateMode = 1;
        // You can customize the amount in WETH to short
        uint256 amountInWethToShort = SOME_WETH_AMOUNT / 10;
        IDebtToken dAsset = interestRateMode == 1 ? sdAsset : vdAsset;
        defiant.openShort____1l(
            amountInWethToShort,
            address(asset),
            interestRateMode,
            UNISWAP_POOL_FEE
        );
        (, uint256 assetPrice) = defiant.calculateAmount_tb_(0, address(asset));
        uint256 dAmount = dAsset.balanceOf(address(this));

        defiant.closeShort___h6U(
            ((dAmount * assetPrice) * 1010) / 1e21,
            address(asset),
            interestRateMode,
            UNISWAP_POOL_FEE
        );
        assertEq(dAsset.balanceOf(address(this)), 0);
        assertGe(aAsset.balanceOf(address(this)), 0);
    }

    function testCannotCloseShortInsufficientFunds() public {
        defiant.startEarningWrapped(SOME_WETH_AMOUNT - 1);
        (, uint256 ltv, , , , , , , , ) = protocolDataProvider
            .getReserveConfigurationData(address(weth));
        // Deposit LINK to ensure only aWETH is considered when assesing borrowing power
        tip(LINK_ADDRESS, address(this), 1000e18);
        (bool sent, ) = LENDING_POOL_ADDRESS.call(
            abi.encodeWithSelector(
                0xe8eda9df,
                LINK_ADDRESS,
                1000e18,
                address(this),
                0
            )
        );
        require(sent);

        vm.expectRevert(
            abi.encodeWithSelector(
                Defiant.InsufficientFunds.selector,
                SOME_WETH_AMOUNT,
                ((SOME_WETH_AMOUNT - 1) * ltv) / 1e4
            )
        );
        defiant.closeShort___h6U(SOME_WETH_AMOUNT, address(asset), 1, 3000);
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
        defiant.update_Xx(
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
        defiant.update_Xx(
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

contract DefiantIntegrationTest is
    DSTest,
    stdCheats,
    AuthorityDeployer,
    AddressBook
{
    // You can customize the amount of WETH to fund users with
    uint256 constant SOME_WETH_AMOUNT = 1 ether;
    // You can customize the uniswap pool fee for `asset1`
    uint24 constant UNISWAP_POOL_FEE_1 = 3000;
    // You can customize the uniswap pool fee for `asset2`
    uint24 constant UNISWAP_POOL_FEE_2 = 3000;

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
    ERC20 asset1;
    ERC20 aAsset1;
    IDebtToken sdAsset1;
    IDebtToken vdAsset1;
    ERC20 asset2;
    ERC20 aAsset2;
    IDebtToken sdAsset2;
    IDebtToken vdAsset2;
    IProtocolDataProvider protocolDataProvider;

    Defiant defiant;

    Vm vm = Vm(HEVM_ADDRESS);

    constructor() {
        weth = ERC20(WETH_ADDRESS);
        // You can customize which asset1 to short
        asset1 = ERC20(DAI_ADDRESS);
        // You can customize which asset2 to short
        asset2 = ERC20(WBTC_ADDRESS);
        protocolDataProvider = IProtocolDataProvider(
            PROTOCOL_DATA_PROVIDER_ADDRESS
        );
        (address aWethAddr, , ) = protocolDataProvider
            .getReserveTokensAddresses(WETH_ADDRESS);
        (
            address aAsset1Addr,
            address sdAsset1Addr,
            address vdAsset1Addr
        ) = protocolDataProvider.getReserveTokensAddresses(address(asset1));
        (
            address aAsset2Addr,
            address sdAsset2Addr,
            address vdAsset2Addr
        ) = protocolDataProvider.getReserveTokensAddresses(address(asset2));
        aWeth = ERC20(aWethAddr);
        aAsset1 = ERC20(aAsset1Addr);
        aAsset2 = ERC20(aAsset2Addr);
        sdAsset1 = IDebtToken(sdAsset1Addr);
        vdAsset1 = IDebtToken(vdAsset1Addr);
        sdAsset2 = IDebtToken(sdAsset2Addr);
        vdAsset2 = IDebtToken(vdAsset2Addr);
    }

    function setUp() public {
        defiant = new Defiant(
            WETH_GATEWAY_ADDRESS,
            LENDING_POOL_ADDRESS_PROVIDER_ADDRESS,
            PROTOCOL_DATA_PROVIDER_ADDRESS,
            SWAP_ROUTER_ADDRESS,
            AUTHORITY_ADDRESS
        );
    }

    function testBasicIntegration() public {
        address alice = address(0xA71CE);
        startHoax(alice, SOME_WETH_AMOUNT * 2);
        tip(WETH_ADDRESS, alice, SOME_WETH_AMOUNT);
        weth.approve(address(defiant), 2**256 - 1);
        aWeth.approve(address(defiant), 2**256 - 1);
        sdAsset1.approveDelegation(address(defiant), 2**256 - 1);
        vdAsset1.approveDelegation(address(defiant), 2**256 - 1);
        sdAsset2.approveDelegation(address(defiant), 2**256 - 1);
        vdAsset2.approveDelegation(address(defiant), 2**256 - 1);
        // You can customize the interest rate mode to use for `asset1` (stable: 1, variable: 2)
        uint256 interestRateMode1 = 1;
        // You can customize the interest rate mode to use for `asset2` (stable: 1, variable: 2)
        uint256 interestRateMode2 = 2;
        // You can customize the amount in WETH to short
        uint256 amountInWethToShort = SOME_WETH_AMOUNT / 10;
        IDebtToken dAsset1 = interestRateMode1 == 1 ? sdAsset1 : vdAsset1;
        IDebtToken dAsset2 = interestRateMode2 == 1 ? sdAsset2 : vdAsset2;

        defiant.startEarning{value: SOME_WETH_AMOUNT}();
        defiant.startEarningWrapped(SOME_WETH_AMOUNT);

        assertGe(aWeth.balanceOf(alice), SOME_WETH_AMOUNT * 2);

        uint256 prevBalanceAlice = aWeth.balanceOf(alice);

        defiant.openShort____1l(
            amountInWethToShort,
            DAI_ADDRESS,
            interestRateMode1,
            UNISWAP_POOL_FEE_1
        );
        defiant.openShort____1l(
            amountInWethToShort,
            WBTC_ADDRESS,
            interestRateMode2,
            UNISWAP_POOL_FEE_2
        );

        (uint256 asset1Amount, ) = defiant.calculateAmount_tb_(
            amountInWethToShort,
            address(asset1)
        );
        (uint256 asset2Amount, ) = defiant.calculateAmount_tb_(
            amountInWethToShort,
            address(asset2)
        );

        uint256 dAmount1 = dAsset1.balanceOf(alice);
        uint256 dAmount2 = dAsset2.balanceOf(alice);
        assertGe(dAmount1, asset1Amount);
        assertGe(dAmount2, asset2Amount);
        assertGe(aWeth.balanceOf(alice), (prevBalanceAlice * 9800) / 1e4);

        (, uint256 asset1Price) = defiant.calculateAmount_tb_(
            0,
            address(asset1)
        );
        (, uint256 asset2Price) = defiant.calculateAmount_tb_(
            0,
            address(asset2)
        );

        defiant.closeShort___h6U(
            ((dAmount1 * asset1Price) * 1010) / 1e21,
            address(asset1),
            interestRateMode1,
            UNISWAP_POOL_FEE_1
        );
        assertEq(dAsset1.balanceOf(alice), 0);
        assertGe(aAsset1.balanceOf(address(this)), 0);

        defiant.closeShort___h6U(
            ((dAmount2 * asset2Price) * 1010) / 1e21,
            address(asset2),
            interestRateMode2,
            UNISWAP_POOL_FEE_2
        );
        assertEq(dAsset2.balanceOf(alice), 0);
        assertGe(aAsset2.balanceOf(address(this)), 0);

        vm.stopPrank();

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
        defiant.update_Xx(
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
}
