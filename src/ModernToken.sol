// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract ModernToken is ERC20 {
    event Hint(string hint);

    address public icoAddr;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol, decimals) {
        icoAddr = address(new Ico(address(this), payable(msg.sender)));
    }

    function hint() public {
        emit Hint("You can make your token do something amazing!");
    }

    function icoMint(address payable to, uint256 amount) public {
        require(msg.sender == icoAddr);
        _mint(to, amount);
    }
}

contract Ico {
    error CannotBuyZeroTokens();

    ModernToken public token;
    uint256 public icoStartTime;
    address payable public owner;

    constructor(address tokenAddr, address payable _owner) {
        token = ModernToken(tokenAddr);
        icoStartTime = block.timestamp;
        owner = _owner;
    }

    function buy() public payable {
        if (msg.value == 0) revert CannotBuyZeroTokens();
        token.icoMint(payable(msg.sender), msg.value);
    }

    function endIco() public {
        require(block.timestamp >= icoStartTime + 1 days);
        selfdestruct(owner);
    }
}
