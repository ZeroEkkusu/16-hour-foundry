// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

abstract contract EthReceiver {
    receive() external payable {}

    fallback() external payable {}
}
