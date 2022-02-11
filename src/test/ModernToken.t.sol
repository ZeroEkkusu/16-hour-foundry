// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {ModernToken, Ico} from "src/ModernToken.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";

contract ModernTokenUnitTest is DSTest, stdCheats {
    event IcoOver();

    ModernToken token;
    Ico ico;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        token = new ModernToken("Token", "TKN", 18);
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
}

contract ModernTokenIntegrationTest is DSTest, stdCheats {
    ModernToken token;
    Ico ico;

    function setUp() public {
        token = new ModernToken("Token", "TKN", 18);
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
