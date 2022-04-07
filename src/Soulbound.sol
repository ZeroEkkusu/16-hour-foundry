// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

/// @notice Soulbound NFT contract based on Vitalik Buterin's blog post
/// @notice https://vitalik.ca/general/2022/01/26/soulbound.html
/// @dev The Soulbound ERC standard does not exist yet!
contract Soulbound {
    error TokenIdCannotBeNonZero();
    error InvalidForSoulbound();
    error Unauthorized();
    error EnsCallFailed();
    error ResolverCallFailed();

    event Updated(address ensAddr);
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    string public constant name = "Soulbound Pug";
    string public constant symbol = "SBP";
    string private constant URI =
        "ipfs:QmfHdx2jYHhimPayeXrsnhSbby2FSBsieQhw5dYkbhhdpR";

    bytes32 private immutable namehash;
    address private ensAddr;

    constructor(bytes32 _namehash, address _ensAddr) {
        namehash = _namehash;
        ensAddr = _ensAddr;
    }

    function tokenURI(uint256 _tokenId) external pure returns (string memory) {
        if (_tokenId != 0) revert TokenIdCannotBeNonZero();
        return URI;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return _owner == resolveAddress() ? 1 : 0;
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        if (_tokenId != 0) revert TokenIdCannotBeNonZero();
        return resolveAddress();
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory data
    ) external payable {
        revert InvalidForSoulbound();
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable {
        revert InvalidForSoulbound();
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable {
        revert InvalidForSoulbound();
    }

    function approve(address _approved, uint256 _tokenId) external pure {
        revert InvalidForSoulbound();
    }

    function setApprovalForAll(address _operator, bool _approved)
        external
        pure
    {
        revert InvalidForSoulbound();
    }

    function getApproved(uint256 _tokenId) external pure returns (address) {
        revert InvalidForSoulbound();
    }

    function isApprovedForAll(address _owner, address _operator)
        external
        pure
        returns (bool)
    {
        return false;
    }

    function supportsInterface(bytes4 interfaceID)
        external
        pure
        returns (bool)
    {
        if (
            interfaceID == 0x01ffc9a7 ||
            interfaceID == 0x80ac58cd ||
            interfaceID == 0x5b5e139f
        ) return true;
    }

    function resolveAddress() private view returns (address) {
        (bool success, bytes memory data) = ensAddr.staticcall(
            abi.encodeWithSignature("resolver(bytes32)", namehash)
        );
        if (!success) revert EnsCallFailed();
        address resolver = abi.decode(data, (address));
        (success, data) = resolver.staticcall(
            abi.encodeWithSignature("addr(bytes32)", namehash)
        );
        if (!success) revert ResolverCallFailed();
        address ownerAddr = abi.decode(data, (address));
        return ownerAddr;
    }

    function update(address _ensAddr) external {
        if (msg.sender != resolveAddress()) revert Unauthorized();
        ensAddr = _ensAddr;
        emit Updated(_ensAddr);
    }
}
