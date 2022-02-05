// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

abstract contract AddressBook {
    /// @dev Contract addresses: https://docs.chain.link/docs/reference-contracts/
    address immutable ETHUSD_PRICE_FEED_ADDRESS;
    /// @dev Contract addresses: https://docs.chain.link/docs/vrf-contracts/
    address immutable VRF_COORDINATOR_ADDRESS;
    bytes32 immutable KEY_HASH;
    uint256 immutable FEE;
    /// @dev Contract addresses: https://docs.chain.link/docs/link-token-contracts/
    address immutable LINK_ADDRESS;

    constructor() {
        address ethUsdPriceFeedAddr;
        address vrfCoordinatorAddr;
        address linkAddr;
        bytes32 keyHash;
        uint256 fee;

        uint256 id;
        assembly {
            id := chainid()
        }
        /// @dev Chain IDs: https://chainlist.org/

        // ETHEREUM MAINNET
        if (id == 1) {
            ethUsdPriceFeedAddr = address(
                0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
            );
            vrfCoordinatorAddr = address(
                0xf0d54349aDdcf704F77AE15b96510dEA15cb7952
            );
            linkAddr = address(0x514910771AF9Ca656af840dff83E8264EcF986CA);
            keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
            fee = 2e18;
        }

        /// @dev Add your networks above

        ETHUSD_PRICE_FEED_ADDRESS = ethUsdPriceFeedAddr;
        VRF_COORDINATOR_ADDRESS = vrfCoordinatorAddr;
        KEY_HASH = keyHash;
        FEE = fee;
        LINK_ADDRESS = linkAddr;
    }
}
