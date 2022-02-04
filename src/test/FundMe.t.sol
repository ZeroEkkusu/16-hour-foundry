// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import {FundMe} from "src/FundMe.sol";
import {MockV3Aggregator} from "src/test/utils/mocks/MockV3Aggregator.sol";

import {DSTest} from "ds-test/test.sol";
import {CheatCodes} from "src/test/utils/ICheatCodes.sol";
import {AuthorityDeployer} from "src/test/utils/AuthorityDeployer.sol";

contract FundMeUnitTest is DSTest, AuthorityDeployer {
    uint256 constant MIN_AMOUNT_IN_USD = 50e18;

    FundMe fundMe;
    address ethUsdPriceFeedAddr;

    // You can customize me!
    uint256 ethPriceInUsd = 1000e18;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    receive() external payable {}

    fallback() external payable {}

    function setUp() public {
        ethUsdPriceFeedAddr = address(
            new MockV3Aggregator(8, int256(ethPriceInUsd / 1e10))
        );
        fundMe = new FundMe(ethUsdPriceFeedAddr, authorityAddr);
    }

    function testGetMinimumAmount() public {
        assertEq(
            fundMe.getMinimumAmount(),
            ((MIN_AMOUNT_IN_USD * 1e18) / ethPriceInUsd)
        );
    }

    function testGetEthPrice() public {
        assertEq(fundMe.getEthPriceInUsd(), ethPriceInUsd);
    }

    function testFund() public {
        assertEq(address(fundMe).balance, 0);
        fundMe.fund{value: 1 ether}();
        assertEq(address(fundMe).balance, 1 ether);
    }

    function testCannotFund() public {
        uint256 minAmount = fundMe.getMinimumAmount();
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

    function testWithdraw() public {
        fundMe.fund{value: 1 ether}();
        uint256 prevBalance = address(this).balance;
        fundMe.withdraw();
        assertEq(address(this).balance, prevBalance + 1 ether);
    }

    function testCannotWithdraw() public {
        cheats.prank(address(0xBAD));
        cheats.expectRevert(bytes("UNAUTHORIZED"));
        fundMe.withdraw();
    }
}

contract FundMeIntegrationTest is DSTest, AuthorityDeployer {
    // You can customize me!
    address constant PRICE_FEED_ADDR =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    FundMe fundMe;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    receive() external payable {}

    fallback() external payable {}

    function setUp() public {
        fundMe = new FundMe(PRICE_FEED_ADDR, authorityAddr);
    }

    function testBasicIntegration() public {
        uint256 amount = fundMe.getMinimumAmount();
        fundMe.fund{value: amount}();
        uint256 prevBalance = address(this).balance;
        fundMe.withdraw();
        assertEq(address(this).balance, prevBalance + amount);
    }
}
