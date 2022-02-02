// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

import "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

contract FundMe {
    error AmountTooLow(uint256 amount, uint256 minAmount);

    mapping(address => uint256) public funderToAmount;
    address[] private funders;

    address public owner;

    AggregatorV3Interface public priceFeed;

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        owner = msg.sender;
    }

    function getMinimumDonationAmount() public view returns (uint256) {
        uint256 minimumUSD = 50e18;
        uint256 price = getPrice();
        return ((minimumUSD * 1e18) / price);
    }

    function fund() public payable {
        uint256 minAmount = getMinimumDonationAmount();
        if (msg.value < minAmount) revert AmountTooLow(msg.value, minAmount);
        funderToAmount[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function getPrice() internal view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer * 1e10);
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
        for (uint256 i = 0; i < funders.length; i++) {
            funderToAmount[funders[i]] = 0;
        }
        funders = new address[](0);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}
