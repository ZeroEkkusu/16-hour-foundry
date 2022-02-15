// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {AggregatorV3Interface} from "chainlink/interfaces/AggregatorV3Interface.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

/// @notice Fund with the minimum amount of USD or more in ETH to get listed as a funder
/// @notice The owner can withdraw funds at any time
contract FundMe is Auth {
    error AmountTooLow(uint256 amount, uint256 minAmount);
    event Withdrawal(uint256 amount);

    uint256 public minimumAmountInUsd;
    mapping(address => uint256) public funderToAmount;
    address[] public funders;

    AggregatorV3Interface internal ethUsdPriceFeed;

    /// @dev Do not send money to the constructor
    /// @dev Optimized for lower deployment cost
    constructor(
        uint256 _minimumAmountInUsd,
        address _ethUsdPriceFeedAddr,
        address _authorityAddr
    ) payable Auth(msg.sender, Authority(_authorityAddr)) {
        minimumAmountInUsd = _minimumAmountInUsd;
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeedAddr);
    }

    /// @dev The average user will save on gas if we prioritize this function
    /// @dev Optimized function name for lower Method ID
    function getMinimumAmount__8X() public view returns (uint256) {
        (, int256 ethPriceInUsd, , , ) = ethUsdPriceFeed.latestRoundData();
        return (minimumAmountInUsd * 1e8) / uint256(ethPriceInUsd);
    }

    function fund() public payable {
        if (msg.value < getMinimumAmount__8X())
            revert AmountTooLow(msg.value, getMinimumAmount__8X());

        unchecked {
            funderToAmount[msg.sender] += msg.value;
        }
        funders.push(msg.sender);
    }

    function withdraw() public requiresAuth {
        uint256 funds = address(this).balance;
        SafeTransferLib.safeTransferETH(msg.sender, funds);
        emit Withdrawal(funds);
        uint256 fundersLength = funders.length;
        unchecked {
            for (uint256 i = 0; i < fundersLength; ++i) {
                funderToAmount[funders[i]] = 0;
            }
        }
        funders = new address[](0);
    }

    function update(uint256 _minimumAmountInUsd, address _ethUsdPriceFeedAddr)
        public
        requiresAuth
    {
        minimumAmountInUsd = _minimumAmountInUsd;
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeedAddr);
    }
}
