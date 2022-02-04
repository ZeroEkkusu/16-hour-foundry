pragma solidity ^0.8.0;

import {MockAuthority} from "solmate/test/utils/mocks/MockAuthority.sol";

abstract contract AuthorityDeployer {
    address authorityAddr = address(new MockAuthority(false));
}
