// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

/// @notice A convenience contract for fetching the right addresses of commonly used contracts
/// @dev Just inherit `AddressBook` in your testing contract and access the addresses
/// @dev If you need more chains, add them after the ETHEREUM MAINNET SETUP
abstract contract AddressBook {
    // CHAINLINK
    address immutable LINK_ADDRESS;
    address immutable ETHUSD_PRICE_FEED_ADDRESS;
    address immutable VRF_COORDINATOR_ADDRESS;
    bytes32 immutable KEY_HASH;
    uint256 immutable FEE;
    // AAVE
    address immutable WETH_GATEWAY_ADDRESS;
    address immutable LENDING_POOL_ADDRESS_PROVIDER_ADDRESS;
    address immutable PROTOCOL_DATA_PROVIDER_ADDRESS;
    // UNISWAP
    address immutable SWAP_ROUTER_ADDRESS;
    // TOKENS
    address immutable WETH_ADDRESS;
    address immutable DAI_ADDRESS;

    constructor() {
        // Chainlink
        address linkAddr;
        address ethUsdPriceFeedAddr;
        address vrfCoordinatorAddr;
        bytes32 keyHash;
        uint256 fee;
        // Aave
        address wethGatewayAddr;
        address lendingPoolAddressesProviderAddr;
        address protocolDataProviderAddr;
        // Uniswap
        address swapRouterAddr;
        // tokens
        address daiAddr;
        address wethAddr; // TODO

        uint256 id = block.chainid;

        // ETHEREUM MAINNET SETUP
        if (id == 1) {
            // Chainlink
            linkAddr = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
            ethUsdPriceFeedAddr = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
            vrfCoordinatorAddr = 0xf0d54349aDdcf704F77AE15b96510dEA15cb7952;
            keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
            fee = 2e18;
            // Aave
            wethGatewayAddr = 0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04;
            lendingPoolAddressesProviderAddr = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
            protocolDataProviderAddr = 0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d;
            // Uniswap
            swapRouterAddr = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
            // tokens
            wethAddr = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            daiAddr = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        }

        // YOU CAN ADD MORE CHAINS ABOVE THIS LINE

        // Chainlink
        LINK_ADDRESS = linkAddr;
        ETHUSD_PRICE_FEED_ADDRESS = ethUsdPriceFeedAddr;
        VRF_COORDINATOR_ADDRESS = vrfCoordinatorAddr;
        KEY_HASH = keyHash;
        FEE = fee;
        // Aave
        WETH_GATEWAY_ADDRESS = wethGatewayAddr;
        LENDING_POOL_ADDRESS_PROVIDER_ADDRESS = lendingPoolAddressesProviderAddr;
        PROTOCOL_DATA_PROVIDER_ADDRESS = protocolDataProviderAddr;
        // Uniswap
        SWAP_ROUTER_ADDRESS = swapRouterAddr;
        // token
        WETH_ADDRESS = wethAddr;
        DAI_ADDRESS = daiAddr;
    }
}
