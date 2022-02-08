// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {AggregatorV3Interface} from "chainlink/interfaces/AggregatorV3Interface.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

/// @notice Fund with 50 USD or more in ETH to get listed as a funder
/// @notice The owner can withdraw funds at any time
contract FundMe is Auth {
    error AmountTooLow(uint256 amount, uint256 minAmount);
    event Withdrawal(uint256 amount);

    mapping(address => uint256) public funderToAmount;
    address[] public funders;

    AggregatorV3Interface public ethUsdPriceFeed;

    constructor(address _ethUsdPriceFeedAddr, address _authorityAddr)
        Auth(msg.sender, Authority(_authorityAddr))
    {
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeedAddr);
    }

    function getMinimumAmount__8X() public view returns (uint256) {
        (, int256 ethPriceInUsd, , , ) = ethUsdPriceFeed.latestRoundData();
        return 50e26 / uint256(ethPriceInUsd);
    }

    function fund() public payable {
        if (msg.value < getMinimumAmount__8X())
            revert AmountTooLow(msg.value, getMinimumAmount__8X());

        funderToAmount[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function withdraw() public requiresAuth {
        SafeTransferLib.safeTransferETH(msg.sender, address(this).balance);
        emit Withdrawal(address(this).balance);
        for (uint256 i = 0; i < funders.length; ++i) {
            funderToAmount[funders[i]] = 0;
        }
        funders = new address[](0);
    }
}
