// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AaveLocker_Fork_Test} from "./_AaveLocker.fork.t.sol";

/**
 * @notice Fork tests for the function "constructor" of contract "AaveLocker".
 */
contract Constructor_AaveLocker_Fork_Test is AaveLocker_Fork_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AaveLocker_Fork_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFork_Success_deployment() public view {
        // When: Deploying AaveV3Locker.
        // Then: Correct variables should be set.
        assertEq(AAVE_LOCKER.owner(), address(EURB));
        assertEq(address(AAVE_LOCKER.AAVE_POOL()), 0xb50201558B00496A145fE76f7424749556E326D8);
        assertEq(address(AAVE_LOCKER.ATOKEN()), aEURE);
    }
}
