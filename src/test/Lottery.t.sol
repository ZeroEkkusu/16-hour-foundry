// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import {Lottery} from "src/Lottery.sol";
import {MockV3Aggregator} from "src/test/utils/mocks/MockV3Aggregator.sol";
import {MockVRFCoordinator} from "src/test/utils/mocks/MockVRFCoordinator.sol";
import {LinkToken} from "src/test/utils/mocks/LinkToken.sol";

import {DSTest} from "ds-test/test.sol";
import {CheatCodes} from "src/test/utils/ICheatCodes.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {AuthorityDeployer} from "src/test/utils/AuthorityDeployer.sol";

contract LotteryUnitTest is DSTest, AuthorityDeployer, stdCheats {
    enum LOTTERY_STATE {
        CLOSED,
        OPEN,
        CALCULATING_WINNER
    }
    uint256 constant ENTRY_FEE_IN_USD = 50e18;

    Lottery lottery;
    address vrfCoordinatorAddr;

    // You can customize me!
    uint256 ethPriceInUsd = 1000e18;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    receive() external payable {}

    fallback() external payable {}

    function setUp() public {
        address ethUsdPriceFeedAddr = address(
            new MockV3Aggregator(8, int256(ethPriceInUsd / 1e10))
        );
        address linkTokenAddr = address(new LinkToken());
        vrfCoordinatorAddr = address(new MockVRFCoordinator(linkTokenAddr));
        lottery = new Lottery(
            ethUsdPriceFeedAddr,
            1e18,
            bytes32(0),
            vrfCoordinatorAddr,
            linkTokenAddr,
            authorityAddr
        );
    }

    function testStartLottery() public {
        lottery.startLottery();
        assertEq(uint256(lottery.lotteryState()), uint256(LOTTERY_STATE.OPEN));
    }
}
