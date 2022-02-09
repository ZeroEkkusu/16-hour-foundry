// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract ModernToken is ERC20 {
    event Hint(string hint);

    address private icoAddr;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol, decimals) {
        icoAddr = address(new ICO(address(this)));
    }

    function hint() public {
        emit Hint("You can make your token do something amazing!");
    }

    function icoMint(address payable to, uint256 amount) public {
        require(msg.sender == icoAddr);
        _mint(to, amount);
    }
}

contract ICO {
    error CannotBuyZeroTokens();

    ModernToken private token;
    uint256 private icoStartTime;
    address payable private owner;

    constructor(address tokenAddr) {
        token = ModernToken(tokenAddr);
        icoStartTime = block.timestamp;
        owner = payable(tx.origin);
    }

    function buy() public payable {
        if (msg.value == 0) revert CannotBuyZeroTokens();
        token.icoMint(payable(msg.sender), msg.value);
    }

    function endICO() public {
        require(block.timestamp >= icoStartTime + 1 days);
        selfdestruct(owner);
    }
}
