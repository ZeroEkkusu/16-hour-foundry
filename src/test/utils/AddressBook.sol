// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

/// @notice A convenience contract for fetching the right addresses of commonly used contracts
/// @dev Just inherit `AddressBook` in your testing contract and access the addresses below
/// @dev If you need more chains, add them after the ETHEREUM MAINNET SETUP
abstract contract AddressBook {
    // CHAINLINK
    address immutable LINK_ADDRESS;
    address immutable ETHUSD_PRICE_FEED_ADDRESS;
    address immutable VRF_COORDINATOR_ADDRESS;
    bytes32 immutable KEY_HASH;
    uint256 immutable FEE;
    address immutable MY_LINK_FAUCET_ADDRESS;
    // AAVE
    address immutable WETH_GATEWAY_ADDRESS;

    constructor() {
        // Chainlink
        address linkAddr;
        address ethUsdPriceFeedAddr;
        address vrfCoordinatorAddr;
        bytes32 keyHash;
        uint256 fee;
        address myLinkFaucetAddr;
        // Aave
        address wethGatewayAddr;

        uint256 id = block.chainid;

        // ETHEREUM MAINNET SETUP
        if (id == 1) {
            // Chainlink
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
            // Aave
            wethGatewayAddr = address(
                0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04
            );
        }

        // YOU CAN ADD MORE CHAINS HERE

        // Chainlink
        LINK_ADDRESS = linkAddr;
        ETHUSD_PRICE_FEED_ADDRESS = ethUsdPriceFeedAddr;
        VRF_COORDINATOR_ADDRESS = vrfCoordinatorAddr;
        KEY_HASH = keyHash;
        FEE = fee;
        MY_LINK_FAUCET_ADDRESS = myLinkFaucetAddr;
        // Aave
        WETH_GATEWAY_ADDRESS = wethGatewayAddr;
    }
}
