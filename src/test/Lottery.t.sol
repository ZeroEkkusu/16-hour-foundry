// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {Lottery} from "src/Lottery.sol";
import {MockV3Aggregator} from "src/test/utils/mocks/MockV3Aggregator.sol";
import {MockVRFCoordinator} from "src/test/utils/mocks/MockVRFCoordinator.sol";
import {LinkToken} from "src/test/utils/mocks/LinkToken.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {AuthorityDeployer} from "src/test/utils/AuthorityDeployer.sol";
import {EthReceiver} from "src/test/utils/EthReceiver.sol";
import {AddressBook} from "src/test/utils/AddressBook.sol";

contract LotteryUnitTest is DSTest, stdCheats, AuthorityDeployer {
    uint256 constant ENTRY_FEE_IN_USD = 50e18;

    Lottery lottery;
    LinkToken link;
    MockVRFCoordinator vrfCoordinator;

    /// @dev Customize the price of ETH in USD
    uint256 ethPriceInUsd;
    /// @dev Customize the request ID when requesting/receiving randomness
    bytes32 requestId;
    /// @dev Customize the randomness
    uint256 randomness;
    /// @dev Customize the fee paid in LINK for randomness
    uint256 fee;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        ethPriceInUsd = 1000e18;
        requestId = bytes32(0);
        randomness = 1337;
        fee = 1e18;

        address ethUsdPriceFeedAddr = address(
            new MockV3Aggregator(8, int256(ethPriceInUsd / 1e10))
        );
        link = new LinkToken();
        vrfCoordinator = new MockVRFCoordinator(address(link));
        lottery = new Lottery(
            ethUsdPriceFeedAddr,
            fee,
            requestId,
            address(vrfCoordinator),
            address(link),
            AUTHORITY_ADDRESS
        );
    }

    function testStartLottery() public {
        lottery.startLottery();
        assertTrue(lottery.lotteryState() == Lottery.LOTTERY_STATE.OPEN);
    }

    function testCannotStartLotteryUnauthorized() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        lottery.startLottery();
    }

    function testCannotStartLotteryTwice() public {
        lottery.startLottery();

        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.FunctionalityLocked.selector,
                Lottery.LOTTERY_STATE.OPEN
            )
        );
        lottery.startLottery();
    }

    function testGetEntryFee() public {
        assertEq(
            lottery.getEntryFee_3_4iR(),
            (ENTRY_FEE_IN_USD * 1e18) / ethPriceInUsd
        );
    }

    function testEnter() public {
        lottery.startLottery();

        lottery.enter_Wrc{value: lottery.getEntryFee_3_4iR()}();
        assertEq(lottery.players(0), address(this));
    }

    function testCannotEnterNotOpen() public {
        uint256 entryFee = lottery.getEntryFee_3_4iR();

        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.FunctionalityLocked.selector,
                Lottery.LOTTERY_STATE.CLOSED
            )
        );
        lottery.enter_Wrc{value: entryFee}();
    }

    function testCannotEnterAmountTooLow() public {
        lottery.startLottery();
        uint256 entryFee = lottery.getEntryFee_3_4iR();
        uint256 amount = entryFee - 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.AmountTooLow.selector,
                amount,
                entryFee
            )
        );
        lottery.enter_Wrc{value: amount}();
    }

    function testEndLottery() public {
        lottery.startLottery();
        link.transfer(address(lottery), 1e18);

        lottery.endLottery();
        assertTrue(
            lottery.lotteryState() == Lottery.LOTTERY_STATE.CALCULATING_WINNER
        );
    }

    function testCannotEndLotteryUnauthorized() public {
        lottery.startLottery();

        vm.expectRevert(bytes("UNAUTHORIZED"));
        vm.prank(address(0xBAD));
        lottery.endLottery();
    }

    function testSelectWinner() public {
        lottery.startLottery();
        uint256 entryFee = lottery.getEntryFee_3_4iR();
        uint256 numOfPlayers = 5;
        for (uint160 i = 0; i < numOfPlayers; ++i) {
            hoax(address(uint160(i)), entryFee);
            lottery.enter_Wrc{value: entryFee}();
        }
        link.transfer(address(lottery), 1e18);
        lottery.endLottery();
        address expectedWinner = lottery.players(randomness % numOfPlayers);
        uint256 prevBalance = expectedWinner.balance;
        uint256 prize = address(lottery).balance;

        vrfCoordinator.callBackWithRandomness(
            requestId,
            randomness,
            address(lottery)
        );
        assertEq(expectedWinner.balance, prevBalance + prize);
    }

    function testCannotSelectWinnerNotSelecting() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.FunctionalityLocked.selector,
                Lottery.LOTTERY_STATE.CLOSED
            )
        );
        vm.prank(address(vrfCoordinator));
        lottery.rawFulfillRandomness(bytes32(0), 1337);
    }
}

contract LotteryIntegrationTest is
    DSTest,
    stdCheats,
    AuthorityDeployer,
    AddressBook
{
    event WinnerSelected(address indexed winner, uint256 randomness);

    Lottery lottery;

    function setUp() public {
        lottery = new Lottery(
            ETHUSD_PRICE_FEED_ADDRESS,
            FEE,
            KEY_HASH,
            VRF_COORDINATOR_ADDRESS,
            LINK_ADDRESS,
            AUTHORITY_ADDRESS
        );
    }

    Vm vm = Vm(HEVM_ADDRESS);

    function testBasicIntegration() public {
        lottery.startLottery();
        uint256 entryFee = lottery.getEntryFee_3_4iR();
        uint256 numOfPlayers = 5;
        for (uint160 i = 1; i <= numOfPlayers; ++i) {
            hoax(address(uint160(i)), entryFee);
            lottery.enter_Wrc{value: entryFee}();
        }
        vm.prank(MY_LINK_FAUCET_ADDRESS);
        LinkToken(LINK_ADDRESS).transfer(address(lottery), FEE);
        lottery.endLottery();
        bytes32 requestId = bytes32(0);
        uint256 randomness = 1337;
        address expectedWinner = lottery.players(randomness % numOfPlayers);
        uint256 prevBalance = address(expectedWinner).balance;
        uint256 prize = address(lottery).balance;
        vm.prank(VRF_COORDINATOR_ADDRESS);
        lottery.rawFulfillRandomness(requestId, randomness);
        assertEq(expectedWinner.balance, prevBalance + prize);
    }
}
