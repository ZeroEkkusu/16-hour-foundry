// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

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

    function testGetMinimumAmount() public {
        assertEq(
            fundMe.getMinimumAmount(),
            (MIN_AMOUNT_IN_USD * 1e18) / ethPriceInUsd
        );
    }

    function testGetEthPrice() public {
        assertEq(fundMe.getEthPriceInUsd(), ethPriceInUsd);
    }

    function testFund() public {
        fundMe.fund{value: 1 ether}();
        assertEq(address(fundMe).balance, 1 ether);
    }

    function testCannotFundAmountTooLow() public {
        uint256 minAmount = fundMe.getMinimumAmount();
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
        fundMe.fund{value: 1 ether}();
        uint256 prevBalance = address(this).balance;
        fundMe.withdraw();
        assertEq(address(this).balance, prevBalance + 1 ether);
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
        uint256 amount = fundMe.getMinimumAmount();
        fundMe.fund{value: amount}();
        uint256 prevBalance = address(this).balance;
        fundMe.withdraw();
        assertEq(address(this).balance, prevBalance + amount);
    }
}
