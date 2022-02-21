// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {ILendingPoolAddressesProvider} from "src/interfaces/ILendingPoolAddressesProvider.sol";
import {IProtocolDataProvider} from "src/interfaces/IProtocolDataProvider.sol";
import {DefiantAave} from "src/DefiantAave.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {AddressBook} from "src/test/utils/AddressBook.sol";

contract DefiantAaveUnitTest is DSTest, AddressBook {
    ERC20 weth;
    ERC20 dai;
    ILendingPoolAddressesProvider lendingPoolAddressProvider;
    IProtocolDataProvider protocolDataProvider;
    ERC20 aWeth;

    DefiantAave defiantAave;
    uint256 amount;
    uint24 daiWethPoolFee = 3000;

    Vm vm = Vm(HEVM_ADDRESS);

    constructor() {
        weth = ERC20(WETH_ADDRESS);
        dai = ERC20(DAI_ADDRESS);
        lendingPoolAddressProvider = ILendingPoolAddressesProvider(
            LENDING_POOL_ADDRESS_PROVIDER_ADDRESS
        );
        protocolDataProvider = IProtocolDataProvider(
            PROTOCOL_DATA_PROVIDER_ADDRESS
        );
        (address aWethAddr, , ) = protocolDataProvider
            .getReserveTokensAddresses(address(weth));
        aWeth = ERC20(aWethAddr);
    }

    function setUp() public {
        // You can customize the amount of DAI to transfer to this contract
        amount = 10000e18;

        defiantAave = new DefiantAave(
            WETH_GATEWAY_ADDRESS,
            LENDING_POOL_ADDRESS_PROVIDER_ADDRESS,
            PROTOCOL_DATA_PROVIDER_ADDRESS,
            SWAP_ROUTER_ADDRESS
        );
        vm.prank(DAI_ADDRESS);
        dai.transfer(address(this), amount);
        dai.approve(address(defiantAave), 2**256 - 1);
    }

    function testStartEarning() public {
        defiantAave.startEarning{value: 1 ether}();
        assertEq(aWeth.balanceOf(address(this)), 1e18);
    }

    function testSwapDaiWeth() public {
        defiantAave.swapExactInputSingle(
            DAI_ADDRESS,
            amount,
            WETH_ADDRESS,
            daiWethPoolFee
        );
        emit log_named_decimal_uint(
            "Amount of WETH received: ",
            weth.balanceOf(address(this)),
            18
        );
    }
}
