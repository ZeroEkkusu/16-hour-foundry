// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import {Lottery} from "src/Lottery.sol";
import {MockV3Aggregator} from "src/test/utils/mocks/MockV3Aggregator.sol";
import {MockVRFCoordinator} from "src/test/utils/mocks/MockVRFCoordinator.sol";
import {LinkToken} from "src/test/utils/mocks/LinkToken.sol";

import {DSTest} from "ds-test/test.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {AuthorityDeployer} from "src/test/utils/AuthorityDeployer.sol";
import {EthReceiver} from "src/test/utils/EthReceiver.sol";

contract LotteryUnitTest is DSTest, stdCheats, AuthorityDeployer, EthReceiver {
    uint256 constant ENTRY_FEE_IN_USD = 50e18;

    Lottery lottery;
    address vrfCoordinatorAddr;

    uint256 ethPriceInUsd;

    Vm vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        ethPriceInUsd = 1000e18;
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
            AUTHORITY_ADDR
        );
    }

    function testStartLottery() public {
        lottery.startLottery();
        assertTrue(lottery.lotteryState() == Lottery.LOTTERY_STATE.OPEN);
    }

    function testGetEntryFee() public {
        assertEq(
            lottery.getEntryFee(),
            (ENTRY_FEE_IN_USD * 1e18) / ethPriceInUsd
        );
    }

    function testGetEthPrice() public {
        assertEq(lottery.getEthPriceInUsd(), ethPriceInUsd);
    }
}
