// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {Lottery} from "src/Lottery.sol";
import {MockV3Aggregator} from "src/test/utils/mocks/MockV3Aggregator.sol";
import {MockVRFCoordinator} from "src/test/utils/mocks/MockVRFCoordinator.sol";
import {LinkToken} from "src/test/utils/mocks/LinkToken.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {AuthorityDeployer} from "src/test/utils/AuthorityDeployer.sol";
import {EthReceiver} from "src/test/utils/EthReceiver.sol";
import {AddressBook} from "src/test/utils/AddressBook.sol";

contract LotteryUnitTest is DSTest, stdCheats, AuthorityDeployer {
    // You can customize the entry fee in USD
    uint256 constant ENTRY_FEE_IN_USD = 50e18;
    // You can customize the price of ETH in USD
    uint256 constant ETH_PRICE_IN_USD = 1000e18;
    // You can customize the randomness
    uint256 constant RANDOMNESS = 1337;
    // You can customize the fee paid in LINK for randomness
    uint256 constant FEE = 1e18;

    event WinnerSelected(address indexed winner, uint256 prize);
    event Updated(
        uint256 _entryFeeInUsd,
        address _ethUsdPriceFeedAddr,
        uint256 _fee,
        bytes32 _keyHash
    );

    Lottery lottery;

    LinkToken link;
    MockVRFCoordinator vrfCoordinator;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        address ethUsdPriceFeedAddr = address(
            new MockV3Aggregator(8, int256(ETH_PRICE_IN_USD / 1e10))
        );
        link = new LinkToken();
        vrfCoordinator = new MockVRFCoordinator(address(link));
        lottery = new Lottery(
            ENTRY_FEE_IN_USD,
            ethUsdPriceFeedAddr,
            FEE,
            bytes32(0),
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
            (ENTRY_FEE_IN_USD * 1e18) / ETH_PRICE_IN_USD
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
        link.transfer(address(lottery), FEE);

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
        // You can customize the number of players
        uint256 numOfPlayers = 5;
        for (uint160 i = 0; i < numOfPlayers; ++i) {
            hoax(address(i), entryFee);
            lottery.enter_Wrc{value: entryFee}();
        }
        link.transfer(address(lottery), FEE);
        lottery.endLottery();
        address expectedWinner = lottery.players(RANDOMNESS % numOfPlayers);
        uint256 prize = address(lottery).balance;
        uint256 prevBalance = expectedWinner.balance;

        vm.expectEmit(true, false, false, true);
        emit WinnerSelected(expectedWinner, prize);
        vrfCoordinator.callBackWithRandomness(
            bytes32(0),
            RANDOMNESS,
            address(lottery)
        );
        assertEq(expectedWinner.balance, prevBalance + prize);
        assertTrue(lottery.lotteryState() == Lottery.LOTTERY_STATE.CLOSED);
        try lottery.players(0) {
            revert();
        } catch {}
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

    function testUpdate() public {
        uint256 newEntryFeeInUsd = ENTRY_FEE_IN_USD * 2;
        address newEthUsdPriceFeedAddr = address(999);
        uint256 newFee = FEE * 2;
        bytes32 newKeyHash = bytes32(uint256(1));

        vm.expectEmit(false, false, false, true);
        emit Updated(
            newEntryFeeInUsd,
            newEthUsdPriceFeedAddr,
            newFee,
            newKeyHash
        );
        lottery.update(
            newEntryFeeInUsd,
            newEthUsdPriceFeedAddr,
            newFee,
            newKeyHash
        );
        assertEq(lottery.entryFeeInUsd(), newEntryFeeInUsd);
        address loadedEthUsdPriceFeedAddr = address(
            uint160(uint256(vm.load(address(lottery), bytes32(uint256(5)))))
        );
        assertEq(loadedEthUsdPriceFeedAddr, newEthUsdPriceFeedAddr);
        bytes32 loadedKeyHash = vm.load(address(lottery), bytes32(uint256(6)));
        assertEq(loadedKeyHash, newKeyHash);
        uint256 loadedFee = uint256(
            vm.load(address(lottery), bytes32(uint256(7)))
        );
        assertEq(loadedFee, newFee);
    }

    function testCannotUpdateUnauthorized() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        lottery.update(0, address(0), 0, bytes32(0));
    }
}

contract LotteryIntegrationTest is
    DSTest,
    stdCheats,
    AuthorityDeployer,
    AddressBook
{
    // You can customize the randomness
    uint256 constant RANDOMNESS = 1337;

    event WinnerSelected(address indexed winner, uint256 prize);
    event Updated(
        uint256 _entryFeeInUsd,
        address _ethUsdPriceFeedAddr,
        uint256 _fee,
        bytes32 _keyHash
    );

    Lottery lottery;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        // You can customize the entry fee in USD
        uint256 entryFeeInUsd = 50;
        lottery = new Lottery(
            entryFeeInUsd,
            ETHUSD_PRICE_FEED_ADDRESS,
            FEE,
            KEY_HASH,
            VRF_COORDINATOR_ADDRESS,
            LINK_ADDRESS,
            AUTHORITY_ADDRESS
        );
    }

    function testBasicIntegration() public {
        lottery.startLottery();

        uint256 entryFee = lottery.getEntryFee_3_4iR();
        // You can customize the number of players
        uint160 numOfPlayers = 5;
        // You can customize how many times to repeat the process
        uint256 times = 2;

        for (uint160 i = 0; i < numOfPlayers * times; ++i) {
            hoax(address(i % numOfPlayers), entryFee);
            lottery.enter_Wrc{value: entryFee}();
        }

        for (uint160 i = 0; i < numOfPlayers * times; ++i) {
            assertEq(lottery.players(i), address(i % numOfPlayers));
        }

        tip(LINK_ADDRESS, address(lottery), FEE);

        lottery.endLottery();

        address expectedWinner = lottery.players(RANDOMNESS % numOfPlayers);
        uint256 prevBalance = address(expectedWinner).balance;
        uint256 prize = address(lottery).balance;

        vm.expectEmit(true, false, false, true);
        emit WinnerSelected(expectedWinner, prize);

        vm.prank(VRF_COORDINATOR_ADDRESS);
        lottery.rawFulfillRandomness(bytes32(0), RANDOMNESS);

        assertEq(expectedWinner.balance, prevBalance + prize);
        assertTrue(lottery.lotteryState() == Lottery.LOTTERY_STATE.CLOSED);
        try lottery.players(0) {
            revert();
        } catch {}

        // You can customize the entry fee in USD
        uint256 newEntryFeeInUsd = entryFee * 2;
        // You can customize the address of the ETHUSD price feed
        address newEthUsdPriceFeedAddr = address(888);
        // You can customize the fee paid in LINK for randomness
        uint256 newFee = 1000;
        // You can customize the key hash
        bytes32 newKeyHash = bytes32(0);

        vm.expectEmit(false, false, false, true);
        emit Updated(
            newEntryFeeInUsd,
            newEthUsdPriceFeedAddr,
            newFee,
            newKeyHash
        );

        lottery.update(
            newEntryFeeInUsd,
            newEthUsdPriceFeedAddr,
            newFee,
            newKeyHash
        );

        assertEq(lottery.entryFeeInUsd(), newEntryFeeInUsd);
        assertEq(
            address(
                uint160(uint256(vm.load(address(lottery), bytes32(uint256(5)))))
            ),
            newEthUsdPriceFeedAddr
        );
        assertEq(vm.load(address(lottery), bytes32(uint256(6))), newKeyHash);
        assertEq(
            uint256(vm.load(address(lottery), bytes32(uint256(7)))),
            newFee
        );
    }
}
