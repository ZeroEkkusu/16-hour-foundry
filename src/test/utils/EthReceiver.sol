// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

/// @notice A convenience contract for receiving ether.
/// @dev Just inherit `EthReceiver` in your testing contract.
abstract contract EthReceiver {
    receive() external payable {}

    fallback() external payable {}
}
