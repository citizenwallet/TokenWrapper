// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract TreasuryV1Extension is TreasuryV1 {
    function setLastSyncTime(uint256 lastSyncTime_) public {
        lastSyncTime = lastSyncTime_;
    }

    function setLastYieldClaim(uint256 lastYieldClaim_) public {
        lastYieldClaim = lastYieldClaim_;
    }

    function getYieldLockersLength() public view returns (uint256 length) {
        length = yieldLockers.length;
    }

    function getWeightsLength() public view returns (uint256 length) {
        length = lockersWeights.length;
    }
}
