// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice An ERC20 token with ICO
contract TokenIco is ERC20 {
    error IcoOver();

    uint256 public immutable icoEndDate;
    address payable immutable icoOwner;

    /// @dev Do not send money to the constructor
    /// @dev Optimized for lower deployment cost
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) payable ERC20(name, symbol, decimals) {
        icoEndDate = block.timestamp + 1 days;
        icoOwner = payable(msg.sender);
    }

    function hint() public returns (string memory) {
        return "You can make the token do something amazing!";
    }

    function icoBuy() public payable {
        if (block.timestamp >= icoEndDate) revert IcoOver();

        _mint(msg.sender, msg.value * 100);
        SafeTransferLib.safeTransferETH(icoOwner, msg.value);
    }
}
