// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EurB} from "../../../src/token/EurB.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";

/**
 * @notice Fuzz tests for the function "transfer" of contract "EurB".
 */
contract Transfer_EurB_Fuzz_Test is EurB_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        EurB_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_Transfer(
        uint128 amount,
        uint256 numberOfRecipients,
        address[5] memory recipients,
        uint256[5] memory rates,
        uint128 id
    ) public {
        // Given: Amount is positive.
        amount = uint128(bound(amount, 1e18, type(uint128).max));

        // And: Commission module is set.
        address commissionModule = address(COMMISSION_MODULE);
        SAFE1.setModule(commissionModule);
        assertEq(SAFE1.isModuleEnabled(commissionModule), true);

        // And: Valid state in the Commission Module.
        id = setValidStateCommissionModule(numberOfRecipients, recipients, rates, id);
        setValidCommissionedInfo(address(SAFE1), id, true);

        // When: Calling transfer.
        EURB.mint(address(SAFE2), amount);
        vm.startPrank(address(SAFE2));
        EURB.transfer(address(SAFE1), amount);

        // Then: The commissions should have been paid.
        (address[] memory recipients_, uint256[] memory rates_) = COMMISSION_MODULE.getCommissionInfo(address(SAFE1));
        for (uint256 i; i < recipients_.length; ++i) {
            uint256 expectedCommission = uint256(amount).mulDivDown(rates_[i], BIPS);
            assertEq(expectedCommission, EURB.balanceOf(recipients_[i]));
        }
    }
}
