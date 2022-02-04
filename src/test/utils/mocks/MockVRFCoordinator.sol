// SPDX-License-Identifier: MIT
// Modified from smartcontractkit/dapptools-starter-kit (https://github.com/smartcontractkit/dapptools-starter-kit). See `NOTICE.md`.

pragma solidity ^0.8.0;

import "chainlink/mocks/VRFCoordinatorMock.sol";

contract MockVRFCoordinator is VRFCoordinatorMock {
    constructor(address linkToken) VRFCoordinatorMock(linkToken) {}
}
