// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

import {MockAuthority} from "solmate/test/utils/mocks/MockAuthority.sol";

/// @notice A convenience contract for deploying a simple, restrictive authority contract.
/// @dev Just inherit `AuthorityDeployer` in your testing contract and access `AUTHORITY_ADDRESS`.
abstract contract AuthorityDeployer {
    address immutable AUTHORITY_ADDRESS = address(new MockAuthority(false));
}
