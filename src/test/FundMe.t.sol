// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {FundMe} from "src/FundMe.sol";
import {MockV3Aggregator} from "src/test/utils/mocks/MockV3Aggregator.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {AuthorityDeployer} from "src/test/utils/AuthorityDeployer.sol";
import {EthReceiver} from "src/test/utils/EthReceiver.sol";
import {AddressBook} from "src/test/utils/AddressBook.sol";

contract FundMeUnitTest is DSTest, AuthorityDeployer, EthReceiver {
    uint256 constant MIN_AMOUNT_IN_USD = 50e18;

    FundMe fundMe;

    /// @dev You can customize the price of ETH in USD
    uint256 ethPriceInUsd;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        ethPriceInUsd = 1000e18;

        address ethUsdPriceFeedAddr = address(
            new MockV3Aggregator(8, int256(ethPriceInUsd / 1e10))
        );
        fundMe = new FundMe(ethUsdPriceFeedAddr, AUTHORITY_ADDRESS);
    }

    function testgetMinimumAmount__8X() public {
        assertEq(
            fundMe.getMinimumAmount__8X(),
            (MIN_AMOUNT_IN_USD * 1e18) / ethPriceInUsd
        );
    }

    function testFund() public {
        uint256 amount = fundMe.getMinimumAmount__8X();

        fundMe.fund{value: amount}();
        assertEq(fundMe.funders(0), address(this));
        assertEq(address(fundMe).balance, amount);
    }

    function testCannotFundAmountTooLow() public {
        uint256 minAmount = fundMe.getMinimumAmount__8X();
        uint256 amount = minAmount - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                FundMe.AmountTooLow.selector,
                amount,
                minAmount
            )
        );
        fundMe.fund{value: amount}();
    }

    function testWithdraw() public {
        uint256 amount = fundMe.getMinimumAmount__8X();
        fundMe.fund{value: amount}();

        uint256 prevBalance = address(this).balance;
        fundMe.withdraw();
        assertEq(address(this).balance, prevBalance + amount);
    }

    function testCannotWithdrawUnauthorized() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        fundMe.withdraw();
    }
}

contract FundMeIntegrationTest is
    DSTest,
    AuthorityDeployer,
    EthReceiver,
    AddressBook
{
    FundMe fundMe;

    function setUp() public {
        fundMe = new FundMe(ETHUSD_PRICE_FEED_ADDRESS, AUTHORITY_ADDRESS);
    }

    function testBasicIntegration() public {
        uint256 amount = fundMe.getMinimumAmount__8X();
        uint256 numOfFunders = 5;
        for (uint256 i = 1; i <= numOfFunders; ++i) {
            fundMe.fund{value: amount}();
        }
        uint256 prevBalance = address(this).balance;
        uint256 funds = address(fundMe).balance;
        fundMe.withdraw();
        assertEq(address(this).balance, prevBalance + funds);
    }
}
