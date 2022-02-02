// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import "src/FundMe.sol";
import "./mocks/MockV3Aggregator.sol";

import "ds-test/test.sol";
import "./interfaces/ICheatCodes.sol";

contract FundMeTest is DSTest {
    FundMe fundMe;
    MockV3Aggregator priceFeed;

    uint256 constant ethPrice = 1000e18;
    uint256 constant minAmountInUSD = 50e18;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    receive() external payable {}

    function setUp() public {
        priceFeed = new MockV3Aggregator(8, int256(ethPrice / 1e10));
        fundMe = new FundMe(address(priceFeed));
    }

    function testGetMinimumDonationAmount() public {
        assertEq(
            fundMe.getMinimumDonationAmount(),
            ((minAmountInUSD * 1e18) / ethPrice)
        );
    }

    function testFund() public {
        assertEq(address(fundMe).balance, 0);
        fundMe.fund{value: 1 ether}();
        assertEq(address(fundMe).balance, 1 ether);
    }

    function testGetEthPrice() public {
        assertEq(fundMe.getEthPrice(), ethPrice);
    }

    function testWithdraw() public {
        fundMe.fund{value: 1 ether}();
        uint256 prevBalance = address(this).balance;
        fundMe.withdraw();
        assertEq(address(this).balance, prevBalance + 1 ether);
    }

    function testBadWithdraw() public {
        cheats.prank(address(1));
        cheats.expectRevert(
            abi.encodeWithSelector(FundMe.Unauthorized.selector)
        );
        fundMe.withdraw();
    }
}
