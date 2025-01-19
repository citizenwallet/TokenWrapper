// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AaveV3Locker} from "../../../src/lockers/AaveLocker.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {Fork_Test} from "../Fork.t.sol";
import {IPoolAddressesProvider} from "../../utils/interfaces/aave/IPoolAddressesProvider.sol";
import {LockerMock} from "../../utils/mocks/LockerMock.sol";

/**
 * @notice Common logic needed by all "AaveLocker" fork tests.
 */
abstract contract AaveLocker_Fork_Test is Fork_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    address public aEURE = 0xEdBC7449a9b594CA4E053D9737EC5Dc4CbCcBfb2;

    IPoolAddressesProvider public poolAddressesProvider =
        IPoolAddressesProvider(0xb50201558B00496A145fE76f7424749556E326D8);

    // We use the Balancer Vault as fund for EURE
    address public EUREFund = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AaveV3Locker public AAVE_LOCKER;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fork_Test) {
        Fork_Test.setUp();

        // Deploy contracts.
        address pool = 0xb50201558B00496A145fE76f7424749556E326D8;
        AAVE_LOCKER = new AaveV3Locker(address(TREASURY), aEURE, pool);
    }

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
}
