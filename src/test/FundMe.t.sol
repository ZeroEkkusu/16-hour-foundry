// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {FundMe} from "src/FundMe.sol";
import {MockV3Aggregator} from "src/test/utils/mocks/MockV3Aggregator.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {AuthorityDeployer} from "src/test/utils/AuthorityDeployer.sol";
import {EthReceiver} from "src/test/utils/EthReceiver.sol";
import {AddressBook} from "src/test/utils/AddressBook.sol";

contract FundMeUnitTest is DSTest, AuthorityDeployer, EthReceiver {
    // You can customize the minimum amount in USD
    uint256 constant MINIMUM_AMOUNT_IN_USD = 50e18;
    // You can customize the price of ETH in USD
    uint256 constant ETH_PRICE_IN_USD = 1000e18;

    event Withdrawal(uint256 amount);
    event Updated(uint256 _minimumAmountInUsd, address _ethUsdPriceFeedAddr);

    FundMe fundMe;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        address ethUsdPriceFeedAddr = address(
            new MockV3Aggregator(8, int256(ETH_PRICE_IN_USD / 1e10))
        );
        fundMe = new FundMe(
            MINIMUM_AMOUNT_IN_USD,
            ethUsdPriceFeedAddr,
            AUTHORITY_ADDRESS
        );
    }

    function testgetMinimumAmount() public {
        assertEq(
            fundMe.getMinimumAmount__8X(),
            (MINIMUM_AMOUNT_IN_USD * 1e18) / ETH_PRICE_IN_USD
        );
    }

    function testFund() public {
        uint256 amount = fundMe.getMinimumAmount__8X();

        fundMe.fund{value: amount}();
        assertEq(address(fundMe).balance, amount);
        assertEq(fundMe.funders(0), address(this));
        assertEq(fundMe.funderToAmount(address(this)), amount);
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
        fundMe.fund{value: fundMe.getMinimumAmount__8X()}();
        uint256 funds = address(fundMe).balance;
        uint256 prevBalance = address(this).balance;

        vm.expectEmit(false, false, false, true);
        emit Withdrawal(funds);
        fundMe.withdraw();
        assertEq(address(this).balance, prevBalance + funds);
        assertEq(fundMe.funderToAmount(address(this)), 0);
        try fundMe.funders(0) {
            revert();
        } catch {}
    }

    function testCannotWithdrawUnauthorized() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        fundMe.withdraw();
    }

    function testUpdate() public {
        uint256 newMinimumAmountInUsd = MINIMUM_AMOUNT_IN_USD * 2;
        address newEthUsdPriceFeedAddr = address(999);

        vm.expectEmit(false, false, false, true);
        emit Updated(newMinimumAmountInUsd, newEthUsdPriceFeedAddr);
        fundMe.update(newMinimumAmountInUsd, newEthUsdPriceFeedAddr);
        assertEq(fundMe.minimumAmountInUsd(), newMinimumAmountInUsd);
        assertEq(
            address(
                uint160(uint256(vm.load(address(fundMe), bytes32(uint256(5)))))
            ),
            newEthUsdPriceFeedAddr
        );
    }

    function testCannotUpdateUnauthorized() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        fundMe.update(0, address(0));
    }
}

contract FundMeIntegrationTest is
    DSTest,
    stdCheats,
    AuthorityDeployer,
    EthReceiver,
    AddressBook
{
    event Withdrawal(uint256 amount);
    event Updated(uint256 _minimumAmountInUsd, address _ethUsdPriceFeedAddr);

    FundMe fundMe;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        // You can customize the minimum amount in USD
        uint256 minimumAmountInUsd = 50e18;

        fundMe = new FundMe(
            minimumAmountInUsd,
            ETHUSD_PRICE_FEED_ADDRESS,
            AUTHORITY_ADDRESS
        );
    }

    function testBasicIntegration() public {
        uint256 amount = fundMe.getMinimumAmount__8X();
        // You can customize the number of funders
        uint160 numOfFunders = 5;
        // You can customize how many times to repeat the process
        uint256 times = 2;

        for (uint160 i = 0; i < numOfFunders * times; ++i) {
            hoax(address(i % numOfFunders));
            fundMe.fund{value: amount}();
        }

        uint256 funds = address(fundMe).balance;

        assertEq(funds, numOfFunders * amount * times);

        for (uint160 i = 0; i < numOfFunders * times; ++i) {
            assertEq(fundMe.funders(i), address(i % numOfFunders));
        }

        for (uint160 i = 0; i < numOfFunders; ++i) {
            assertEq(fundMe.funderToAmount(address(i)), amount * times);
        }

        uint256 prevBalance = address(this).balance;

        vm.expectEmit(false, false, false, true);
        emit Withdrawal(funds);

        fundMe.withdraw();

        assertEq(address(this).balance, prevBalance + funds);

        for (uint160 i = 0; i < numOfFunders; ++i) {
            assertEq(fundMe.funderToAmount(address(i)), 0);
        }
        try fundMe.funders(0) {
            revert();
        } catch {}

        // You can customize the minimum amount in USD
        uint256 newMinimumAmountInUsd = amount * 2;
        // You can customize the address of the ETHUSD price feed
        address newEthUsdPriceFeedAddr = address(999);

        vm.expectEmit(false, false, false, true);
        emit Updated(newMinimumAmountInUsd, newEthUsdPriceFeedAddr);

        fundMe.update(newMinimumAmountInUsd, newEthUsdPriceFeedAddr);

        assertEq(fundMe.minimumAmountInUsd(), newMinimumAmountInUsd);
        assertEq(
            address(
                uint160(uint256(vm.load(address(fundMe), bytes32(uint256(5)))))
            ),
            newEthUsdPriceFeedAddr
        );
    }
}
