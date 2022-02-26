// SPDX-License-Identifier: agpl-3.0
// Modified from aave/protocol-v2 (https://github.com/aave/protocol-v2). See `NOTICE.md`.
// Change Solidity version from `0.6.12` to `^0.8.0`
// Add `getWETHAddress` function signature

pragma solidity ^0.8.0;

interface IWETHGateway {
    function getWETHAddress() external view returns (address);

    function depositETH(
        address lendingPool,
        address onBehalfOf,
        uint16 referralCode
    ) external payable;

    function withdrawETH(
        address lendingPool,
        uint256 amount,
        address onBehalfOf
    ) external;

    function repayETH(
        address lendingPool,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external payable;

    function borrowETH(
        address lendingPool,
        uint256 amount,
        uint256 interesRateMode,
        uint16 referralCode
    ) external;
}
