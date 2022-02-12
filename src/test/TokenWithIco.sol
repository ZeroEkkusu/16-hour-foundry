// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {TokenWithIco, Ico} from "src/TokenWithIco.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";

contract TokenWithIcoUnitTest is DSTest, stdCheats {
    event IcoOver();

    TokenWithIco token;
    Ico ico;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        token = new TokenWithIco("Token", "TKN", 18);
        ico = Ico(token.icoAddr());
    }

    function testBuy(uint96 amount) public {
        ico.buy{value: amount}();
        assertEq(token.balanceOf(address(this)), amount);
    }

    function testFailBuyIcoOver() public {
        address alice = address(0xA71CE);
        skip(1 days);
        ico.endIco();

        hoax(alice);
        ico.buy{value: 1 ether}();
    }

    function testCannotBuyZeroTokens() public {
        vm.expectRevert(
            abi.encodeWithSelector(Ico.CannotBuyZeroTokens.selector)
        );
        ico.buy();
    }

    function testFailMintTokensUnauthorized() public {
        token.icoMint(payable(address(this)), 1);
    }

    function testEndIco() public {
        uint256 amount = 1 ether;
        ico.buy{value: amount}();
        skip(1 days);
        uint256 prevBalance = address(this).balance;

        vm.expectEmit(false, false, false, false);
        emit IcoOver();
        ico.endIco();
        assertEq(address(this).balance, prevBalance + amount);
    }

    function testFailEndIcoNotOver() public {
        ico.endIco();
    }

    function testFailEndIcoTwice() public {
        skip(1 days);
        ico.endIco();

        ico.endIco();
    }
}

contract TokenWithIcoIntegrationTest is DSTest, stdCheats {
    TokenWithIco token;
    Ico ico;

    function setUp() public {
        token = new TokenWithIco("Token", "TKN", 18);
        ico = Ico(token.icoAddr());
    }

    function testBasicIntegration() public {
        for (uint160 i = 0; i < 5; ++i) {
            address buyer = address(i);
            uint256 amount = 1 ether;
            hoax(buyer);
            ico.buy{value: amount}();
            assertEq(token.balanceOf(buyer), amount);
        }
        skip(1 days);
        uint256 prevBalance = address(this).balance;
        uint256 money = address(ico).balance;
        ico.endIco();
        assertEq(address(this).balance, prevBalance + money);
    }
}
