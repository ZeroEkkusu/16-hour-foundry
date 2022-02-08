// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

/// @notice A convenience contract for fetching the right addresses of commonly used contracts
/// @dev Just inherit `AddressBook` in your testing contract and access the addresses below
/// @dev If you need more chains, add them after the ETHEREUM MAINNET setup
abstract contract AddressBook {
    // CHAINLINK CONTRACTS
    address immutable LINK_ADDRESS;
    address immutable ETHUSD_PRICE_FEED_ADDRESS;
    address immutable VRF_COORDINATOR_ADDRESS;
    bytes32 immutable KEY_HASH;
    uint256 immutable FEE;
    address immutable MY_LINK_FAUCET_ADDRESS;

    constructor() {
        address linkAddr;
        address ethUsdPriceFeedAddr;
        address vrfCoordinatorAddr;
        bytes32 keyHash;
        uint256 fee;
        address myLinkFaucetAddr;

        uint256 id;
        assembly {
            id := chainid()
        }

        // ETHEREUM MAINNET
        if (id == 1) {
            linkAddr = address(0x514910771AF9Ca656af840dff83E8264EcF986CA);
            ethUsdPriceFeedAddr = address(
                0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
            );
            vrfCoordinatorAddr = address(
                0xf0d54349aDdcf704F77AE15b96510dEA15cb7952
            );
            keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
            fee = 2e18;
            myLinkFaucetAddr = address(
                0x98C63b7B319dFBDF3d811530F2ab9DfE4983Af9D
            );
        }

        // ...

        LINK_ADDRESS = linkAddr;
        ETHUSD_PRICE_FEED_ADDRESS = ethUsdPriceFeedAddr;
        VRF_COORDINATOR_ADDRESS = vrfCoordinatorAddr;
        KEY_HASH = keyHash;
        FEE = fee;
        MY_LINK_FAUCET_ADDRESS = myLinkFaucetAddr;
    }
}
