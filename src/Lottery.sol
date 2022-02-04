// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "chainlink/interfaces/AggregatorV3Interface.sol";
import {VRFConsumerBase} from "chainlink/VRFConsumerBase.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

contract Lottery is VRFConsumerBase, Auth {
    error FunctionalityLocked(LOTTERY_STATE lotteryState);
    error AmountTooLow(uint256 amount, uint256 entryFee);
    error RandomnessNotFound();
    event WinnerSelected(address indexed winner, uint256 _randomness);
    enum LOTTERY_STATE {
        CLOSED,
        OPEN,
        CALCULATING_WINNER
    }
    uint256 constant ENTRY_FEE_IN_USD = 50e18;

    LOTTERY_STATE public lotteryState;
    address payable[] public players;

    AggregatorV3Interface public priceFeed;
    bytes32 public keyHash;
    uint256 public fee;

    constructor(
        address _priceFeedAddr,
        uint256 _fee,
        bytes32 _keyHash,
        address _vrfCoordinatorAddr,
        address _linkAddr,
        address _authorityAddr
    )
        VRFConsumerBase(_vrfCoordinatorAddr, _linkAddr)
        Auth(msg.sender, Authority(_authorityAddr))
    {
        priceFeed = AggregatorV3Interface(_priceFeedAddr);
        fee = _fee;
        keyHash = _keyHash;
    }

    function startLottery() public requiresAuth {
        if (lotteryState != LOTTERY_STATE.CLOSED)
            revert FunctionalityLocked(lotteryState);

        lotteryState = LOTTERY_STATE.OPEN;
    }

    function getEntryFee() public view returns (uint256) {
        uint256 ethPriceInUsd = getEthPriceInUsd();
        return (ENTRY_FEE_IN_USD * 1e18) / ethPriceInUsd;
    }

    function getEthPriceInUsd() public view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer * 1e10);
    }

    function enter() public payable {
        if (lotteryState != LOTTERY_STATE.OPEN)
            revert FunctionalityLocked(lotteryState);
        uint256 entryFee = getEntryFee();
        if (msg.value < entryFee) revert AmountTooLow(msg.value, entryFee);

        players.push(payable(msg.sender));
    }

    function endLottery() public requiresAuth returns (bytes32) {
        lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        if (lotteryState != LOTTERY_STATE.CALCULATING_WINNER)
            revert FunctionalityLocked(lotteryState);
        if (_randomness <= 0) revert RandomnessNotFound();

        address payable winner = players[_randomness % players.length];

        SafeTransferLib.safeTransferETH(winner, address(this).balance);
        emit WinnerSelected(winner, _randomness);

        players = new address payable[](0);
        lotteryState = LOTTERY_STATE.CLOSED;
    }
}
