// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import "src/FundMe.sol";
import "./mocks/MockV3Aggregator.sol";

import "ds-test/test.sol";
import "./interfaces/ICheatCodes.sol";

contract FundMeUnitTest is DSTest {
    uint256 constant MIN_AMOUNT_IN_USD = 50e18;

    FundMe fundMe;
    address priceFeedAddr;

    // You can customize me!
    uint256 ethPrice = 1000e18;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    receive() external payable {}

    fallback() external payable {}

    function setUp() public {
        priceFeedAddr = address(
            new MockV3Aggregator(8, int256(ethPrice / 1e10))
        );
        fundMe = new FundMe(priceFeedAddr);
    }

    function testGetMinimumFundingAmount() public {
        assertEq(
            fundMe.getMinimumFundingAmount(),
            ((MIN_AMOUNT_IN_USD * 1e18) / ethPrice)
        );
    }

    function testFund() public {
        assertEq(address(fundMe).balance, 0);
        fundMe.fund{value: 1 ether}();
        assertEq(address(fundMe).balance, 1 ether);
    }

    function testCannotFund() public {
        uint256 minAmount = fundMe.getMinimumFundingAmount();
        uint256 amount = minAmount - 1;
        cheats.expectRevert(
            abi.encodeWithSelector(
                FundMe.AmountTooLow.selector,
                amount,
                minAmount
            )
        );
        fundMe.fund{value: amount}();
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

    function testCannotWithdraw() public {
        cheats.prank(address(1));
        cheats.expectRevert(
            abi.encodeWithSelector(FundMe.Unauthorized.selector)
        );
        fundMe.withdraw();
    }
}

contract FundMeIntegrationTest is DSTest {
    // You can customize me!
    address constant PRICE_FEED_ADDR =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    FundMe fundMe;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    receive() external payable {}

    fallback() external payable {}

    function setUp() public {
        fundMe = new FundMe(PRICE_FEED_ADDR);
    }

    function testBasicIntegration() public {
        uint256 amount = fundMe.getMinimumFundingAmount();
        fundMe.fund{value: amount}();
        uint256 prevBalance = address(this).balance;
        fundMe.withdraw();
        assertEq(address(this).balance, prevBalance + amount);
    }
}
