// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {AggregatorV3Interface} from "chainlink/interfaces/AggregatorV3Interface.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

contract FundMe is Auth {
    error AmountTooLow(uint256 amount, uint256 minAmount);
    event Withdrawal(uint256 amount);
    uint256 constant MIN_AMOUNT_IN_USD = 50e18;

    mapping(address => uint256) public funderToAmount;
    address[] public funders;

    AggregatorV3Interface public ethUsdPriceFeed;

    constructor(address _ethUsdPriceFeedAddr, address _authorityAddr)
        Auth(msg.sender, Authority(_authorityAddr))
    {
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeedAddr);
    }

    function getMinimumAmount() public view returns (uint256) {
        (, int256 ethPriceInUsd, , , ) = ethUsdPriceFeed.latestRoundData();
        return (MIN_AMOUNT_IN_USD * 1e8) / uint256(ethPriceInUsd);
    }

    function fund() public payable {
        uint256 minAmount = getMinimumAmount();
        if (msg.value < minAmount) revert AmountTooLow(msg.value, minAmount);
        funderToAmount[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function withdraw() public requiresAuth {
        uint256 amount = address(this).balance;
        SafeTransferLib.safeTransferETH(msg.sender, amount);
        emit Withdrawal(amount);
        for (uint256 i = 0; i < funders.length; ++i) {
            funderToAmount[funders[i]] = 0;
        }
        funders = new address[](0);
    }
}
