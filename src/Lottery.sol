// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {AggregatorV3Interface} from "chainlink/interfaces/AggregatorV3Interface.sol";
import {VRFConsumerBase} from "chainlink/VRFConsumerBase.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

/// @notice Enter the lottery with 50 USD in ETH for a chance to win the prize of other players' fees
contract Lottery is VRFConsumerBase, Auth {
    error FunctionalityLocked(LOTTERY_STATE lotteryState);
    error AmountTooLow(uint256 amount, uint256 entryFee);
    event WinnerSelected(address indexed winner, uint256 _randomness);
    enum LOTTERY_STATE {
        CLOSED,
        OPEN,
        CALCULATING_WINNER
    }

    LOTTERY_STATE public lotteryState;
    address payable[] public players;

    AggregatorV3Interface public ethUsdPriceFeed;
    bytes32 public keyHash;
    uint256 public fee;

    constructor(
        address _ethUsdPriceFeedAddr,
        uint256 _fee,
        bytes32 _keyHash,
        address _vrfCoordinatorAddr,
        address _linkTokenAddr,
        address _authorityAddr
    )
        VRFConsumerBase(_vrfCoordinatorAddr, _linkTokenAddr)
        Auth(msg.sender, Authority(_authorityAddr))
    {
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeedAddr);
        fee = _fee;
        keyHash = _keyHash;
    }

    function startLottery() public requiresAuth {
        if (lotteryState != LOTTERY_STATE.CLOSED)
            revert FunctionalityLocked(lotteryState);

        lotteryState = LOTTERY_STATE.OPEN;
    }

    function getEntryFee_3_4iR() public view returns (uint256) {
        (, int256 ethPriceInUsd, , , ) = ethUsdPriceFeed.latestRoundData();
        return 50e26 / uint256(ethPriceInUsd);
    }

    function enter_Wrc() public payable {
        if (lotteryState != LOTTERY_STATE.OPEN)
            revert FunctionalityLocked(lotteryState);
        if (msg.value < getEntryFee_3_4iR())
            revert AmountTooLow(msg.value, getEntryFee_3_4iR());

        players.push(payable(msg.sender));
    }

    function endLottery() public requiresAuth {
        lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
        requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        if (lotteryState != LOTTERY_STATE.CALCULATING_WINNER)
            revert FunctionalityLocked(lotteryState);
        require(_randomness > 0);

        address payable winner = players[_randomness % players.length];

        SafeTransferLib.safeTransferETH(winner, address(this).balance);
        emit WinnerSelected(winner, _randomness);

        players = new address payable[](0);
        lotteryState = LOTTERY_STATE.CLOSED;
    }
}
