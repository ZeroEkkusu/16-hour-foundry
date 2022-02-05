// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

import {MockAuthority} from "solmate/test/utils/mocks/MockAuthority.sol";

abstract contract AuthorityDeployer {
    address immutable AUTHORITY_ADDRESS = address(new MockAuthority(false));
}
