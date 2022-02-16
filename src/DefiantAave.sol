// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {IWETHGateway} from "aave/misc/interfaces/IWETHGateway.sol";

contract DefiantAave {
    IWETHGateway internal wethGateway;

    constructor(wethGatewayAddr) payable {
        wethGateway = IWETHGateway(wethGatewayAddr);
    }
}
