// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract StorageV1 {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // 1 BIPS = 0,01%
    uint256 internal constant BIPS = 10_000;
    // Max number of active yield lockers.
    uint256 internal constant MAX_YIELD_LOCKERS = 5;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The address of the EURE token accepted in the treasury.
    address public EURE;
    // The address of the owner.
    address public owner;
    // Reentrancy guard.
    uint256 internal locked;
    // An array with active yield lockers.
    address[] public yieldLockers;
    // An array containing the weight of each locker, sum of weights should equal BIPS (100%).
    uint256[] public lockersWeights;
    // The percentage of the totalSupply that should remain idle in the contract.
    uint256 public idleRatio;
    // The last block.timestamp at which the function syncAll() was triggered.
    uint256 public lastSyncTime;
    // The last block.timestamp at which the function collectYield() was called.
    uint256 public lastYieldClaim;
    // The minimum window between two yield claims.
    uint256 public yieldInterval;
    // The total amount deposited in private lockers.
    uint256 public privateLockersSupply;
    // Keeps track of yield accrued and not yet claimed.
    uint256 public availableYield;

    // A mapping indicating if a yield locker is a private locker.
    mapping(address locker => bool isPrivate) public isPrivateLocker;
}
