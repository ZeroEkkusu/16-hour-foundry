// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import "src/Soulbound.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

contract SoulboundTest is DSTest {
    event Updated(address ensAddr);

    address constant ENS_ADDRESS = 0x314159265dD8dbb310642f98f50C066173C1259b;
    bytes32 constant NAMEHASH =
        0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835;
    address constant OWNER_ADDRESS = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    Soulbound soulbound;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        soulbound = new Soulbound(NAMEHASH, ENS_ADDRESS);
    }

    function testName() public {
        assertEq(soulbound.name(), "Soulbound Pug");
    }

    function testSymbol() public {
        assertEq(soulbound.symbol(), "SBP");
    }

    function testTokenUriIdZero() public {
        assertEq(
            soulbound.tokenURI(0),
            "ipfs:QmfHdx2jYHhimPayeXrsnhSbby2FSBsieQhw5dYkbhhdpR"
        );
    }

    function testCannotGetTokenUriIdNonZero(uint256 tokenId) public {
        vm.expectRevert(
            abi.encodeWithSelector(Soulbound.TokenIdCannotBeNonZero.selector)
        );
        vm.assume(tokenId != 0);
        soulbound.tokenURI(tokenId);
    }

    function testBalanceOfOwner() public {
        assertEq(soulbound.balanceOf(OWNER_ADDRESS), 1);
    }

    function testBalanceOfNonOwner(address addr) public {
        vm.assume(addr != OWNER_ADDRESS);
        assertEq(soulbound.balanceOf(addr), 0);
    }

    function testOwnerOfIdZero() public {
        assertEq(soulbound.ownerOf(0), OWNER_ADDRESS);
    }

    function testCannotGetOwnerOfIdNonZero(uint256 tokenId) public {
        vm.expectRevert(
            abi.encodeWithSelector(Soulbound.TokenIdCannotBeNonZero.selector)
        );
        vm.assume(tokenId != 0);
        soulbound.ownerOf(tokenId);
    }

    function testCannotSafeTransferFromWithDataInvalid() public {
        vm.expectRevert(
            abi.encodeWithSelector(Soulbound.InvalidForSoulbound.selector)
        );
        soulbound.safeTransferFrom(address(0), address(0), 0, bytes(""));
    }

    function testCannotSafeTransferFromWithoutDataInvalid() public {
        vm.expectRevert(
            abi.encodeWithSelector(Soulbound.InvalidForSoulbound.selector)
        );
        soulbound.safeTransferFrom(address(0), address(0), 0);
    }

    function testCannotTransferFromInvalid() public {
        vm.expectRevert(
            abi.encodeWithSelector(Soulbound.InvalidForSoulbound.selector)
        );
        soulbound.safeTransferFrom(address(0), address(0), 0);
    }

    function testCannotApproveInvalid() public {
        vm.expectRevert(
            abi.encodeWithSelector(Soulbound.InvalidForSoulbound.selector)
        );
        soulbound.approve(address(0), 0);
    }

    function testCannotSetApprovalForAllInvalid() public {
        vm.expectRevert(
            abi.encodeWithSelector(Soulbound.InvalidForSoulbound.selector)
        );
        soulbound.setApprovalForAll(address(0), true);
    }

    function testCannotGetApprovedInvalid() public {
        vm.expectRevert(
            abi.encodeWithSelector(Soulbound.InvalidForSoulbound.selector)
        );
        soulbound.getApproved(0);
    }

    function testIsApprovedForAll() public {
        assert(!soulbound.isApprovedForAll(address(0), address(0)));
    }

    function testSupportsInterface() public {
        assert(soulbound.supportsInterface(0x01ffc9a7));
        assert(soulbound.supportsInterface(0x80ac58cd));
        assert(soulbound.supportsInterface(0x5b5e139f));
    }

    function testSupportsInterfaceRandom(bytes4 randomInterface) public {
        vm.assume(randomInterface != 0x01ffc9a7);
        vm.assume(randomInterface != 0x80ac58cd);
        vm.assume(randomInterface != 0x5b5e139f);
        assert(!soulbound.supportsInterface(randomInterface));
    }

    function testUpdate() public {
        vm.prank(OWNER_ADDRESS);
        address newEnsAddr = address(999);
        vm.expectEmit(false, false, false, true);
        emit Updated(newEnsAddr);
        soulbound.update(newEnsAddr);
        address loadedEnsAddr = address(
            uint160(uint256(vm.load(address(soulbound), bytes32(uint256(0)))))
        );
        assertEq(loadedEnsAddr, newEnsAddr);
    }

    function testCannotUpdateUnauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(Soulbound.Unauthorized.selector)
        );
        vm.prank(address(0xBAD));
        soulbound.update(address(0));
    }
}
