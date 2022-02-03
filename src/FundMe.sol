// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

import "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import "solmate/utils/SafeTransferLib.sol";

contract FundMe {
    error AmountTooLow(uint256 amount, uint256 minAmount);
    error Unauthorized();

    mapping(address => uint256) public funderToAmount;
    address[] public funders;

    address public owner;

    AggregatorV3Interface public priceFeed;

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        owner = msg.sender;
    }

    function getMinimumFundingAmount() public view returns (uint256) {
        uint256 minAmountInUSD = 50e18;
        uint256 ethPrice = getEthPrice();
        return ((minAmountInUSD * 1e18) / ethPrice);
    }

    function fund() public payable {
        uint256 minAmount = getMinimumFundingAmount();
        if (msg.value < minAmount) revert AmountTooLow(msg.value, minAmount);
        funderToAmount[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function getEthPrice() public view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer * 1e10);
    }

    function withdraw() public onlyOwner {
        SafeTransferLib.safeTransferETH(msg.sender, address(this).balance);
        for (uint256 i = 0; i < funders.length; i++) {
            funderToAmount[funders[i]] = 0;
        }
        funders = new address[](0);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
}
