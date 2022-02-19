// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {DefiantAave} from "src/DefiantAave.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {AddressBook} from "src/test/utils/AddressBook.sol";

contract DefiantAaveUnitTest is DSTest, AddressBook {
    ERC20 weth;
    ERC20 dai;

    DefiantAave defiantAave;
    uint256 amount;
    uint24 daiWethPoolFee = 3000;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        // You can customize the amount of DAI to transfer to this contract
        amount = 10000e18;

        defiantAave = new DefiantAave(
            WETH_GATEWAY_ADDRESS,
            SWAP_ROUTER_ADDRESS
        );
        weth = ERC20(WETH_ADDRESS);
        dai = ERC20(DAI_ADDRESS);
        vm.prank(DAI_ADDRESS);
        dai.transfer(address(this), amount);
        dai.approve(address(defiantAave), 2**256 - 1);
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
