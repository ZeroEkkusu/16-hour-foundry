// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {TokenIco} from "src/TokenIco.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {EthReceiver} from "src/test/utils/EthReceiver.sol";

contract TokenIcoUnitTest is DSTest, stdCheats, EthReceiver {
    TokenIco token;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        token = new TokenIco("Token", "TKN", 18);
    }

    function testIcoBuy(uint96 amount) public {
        uint256 prevBalance = address(this).balance;

        address buyer = address(1);
        hoax(buyer);
        token.icoBuy{value: amount}();
        assertEq(token.balanceOf(buyer), uint256(amount) * 100);
        assertEq(address(this).balance, prevBalance + amount);
    }

    function testCannotIcoBuyIcoOver() public {
        skip(1 days);

        vm.expectRevert(abi.encodeWithSelector(TokenIco.IcoOver.selector));
        hoax(address(1), 1 ether);
        token.icoBuy{value: 1 ether}();
    }
}

contract TokenIcoIntegrationTest is DSTest, stdCheats, EthReceiver {
    TokenIco token;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        token = new TokenIco("Token", "TKN", 18);
    }

    function testBasicIntegration() public {
        // You can customize the number of buyers
        uint160 numOfBuyers = 5;
        // You can customize how much the buyers buy in ETH
        uint256 amount = 1 ether;
        // You can customize how many times to repeat the proccess
        uint256 times = 2;
        uint256 prevBalance = address(this).balance;

        for (uint160 i = 0; i < numOfBuyers * times; ++i) {
            hoax(address(i % numOfBuyers));
            token.icoBuy{value: amount}();
        }

        for (uint160 i = 0; i < numOfBuyers; ++i) {
            assertEq(token.balanceOf(address(i)), amount * 100 * times);
        }

        assertEq(
            address(this).balance,
            prevBalance + numOfBuyers * amount * times
        );

        skip(1 days);

        vm.expectRevert(TokenIco.IcoOver.selector);
        token.icoBuy();
    }
}
