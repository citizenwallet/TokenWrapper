// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB} from "../../../src/token/EurB.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract EurBExtension is EurB {
    constructor(IERC20 underlyingToken, address treasury_, address cardFactory_)
        EurB(underlyingToken, treasury_, cardFactory_)
    {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function setLastSyncTime(uint256 lastSyncTime_) public {
        lastSyncTime = lastSyncTime_;
    }

    function setLastYieldClaim(uint256 lastYieldClaim_) public {
        lastYieldClaim = lastYieldClaim_;
    }
}
