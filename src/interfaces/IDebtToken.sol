// SPDX-License-Identifier: agpl-3.0
// Modified from aave/protocol-v2 (https://github.com/aave/protocol-v2). See `NOTICE.md`.
// Rename file from `IStableDebtToken.sol` to `IDebtToken.sol`
// Import `ERC20` interface
// Change Solidity version from `0.6.12` to `^0.8.0`
// Rename interface from `IStableDebtToken` to `IDebtToken`
// Delete everything except `approveDelegation` and `borrowAllowance`

import {IERC20} from "src/interfaces/IERC20.sol";

pragma solidity ^0.8.0;

/**
 * @author Aave
 **/

interface IDebtToken is IERC20 {
    /**
     * @dev delegates borrowing power to a user on the specific debt token
     * @param delegatee the address receiving the delegated borrowing power
     * @param amount the maximum amount being delegated. Delegation will still
     * respect the liquidation constraints (even if delegated, a delegatee cannot
     * force a delegator HF to go below 1)
     **/
    function approveDelegation(address delegatee, uint256 amount) external;

    /**
     * @dev returns the borrow allowance of the user
     * @param fromUser The user to giving allowance
     * @param toUser The user to give allowance to
     * @return the current allowance of toUser
     **/
    function borrowAllowance(address fromUser, address toUser)
        external
        view
        returns (uint256);
}
