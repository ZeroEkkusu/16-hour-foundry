// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {ModernToken, Ico} from "src/ModernToken.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";

contract ModernTokenUnitTest is DSTest, stdCheats {
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
        ico.endIco();
        assertEq(address(this).balance, prevBalance + amount);
    }

    function testFailEndIcoNotOver() public {
        ico.endIco();
    }
}
