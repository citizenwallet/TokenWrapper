// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract CommissionModule is Ownable {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // 1 BIPS = 0,01%
    uint256 public constant BIPS = 10_000;

    // Max commission per payment is 20% of paid amount.
    uint256 public constant MAX_COMMISSION = 2_000;

    // Max commission recipients.
    uint256 public constant MAX_RECIPIENTS = 5;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // A mapping from a commissioned to a struct with its group id and commission expiry.
    mapping(address commissioned => CommissionedInfo) public commissionedInfo;

    // Maps a commissionGroupId to its corresponding commission details.
    mapping(uint256 commissionGroupId => CommissionGroupInfo) internal commissionGroupInfo;

    struct CommissionedInfo {
        // The commission group id.
        uint128 groupId;
        // Timestamp until when the commission will be applied.
        uint128 validUntil;
    }

    struct CommissionGroupInfo {
        // The commission recipients.
        address[] recipients;
        // The commission rate per receiver in BIPS.
        uint256[] rates;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error LengthMismatch();
    error MaxCommissionRate();
    error MaxRecipients();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() Ownable(msg.sender) {}

    /* //////////////////////////////////////////////////////////////
                             FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    function setCommissionGroupInfo(uint256 commissionGroupId, address[] memory recipients_, uint256[] memory rates_)
        external
        onlyOwner
    {
        if (recipients_.length > 5) revert MaxRecipients();
        if (recipients_.length != rates_.length) revert LengthMismatch();
        uint256 totalRate;
        for (uint256 i; i < rates_.length; ++i) {
            totalRate += rates_[i];
        }
        if (totalRate > MAX_COMMISSION) revert MaxCommissionRate();

        CommissionGroupInfo memory info = CommissionGroupInfo({recipients: recipients_, rates: rates_});

        commissionGroupInfo[commissionGroupId] = info;
    }

    function setCommissionedInfo(address commissioned, uint128 groupId_, uint128 validUntil_) external onlyOwner {
        CommissionedInfo memory info = CommissionedInfo({groupId: groupId_, validUntil: validUntil_});

        commissionedInfo[commissioned] = info;
    }

    /* //////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    function getCommissionInfo(address commissioned)
        external
        view
        returns (address[] memory recipients, uint256[] memory rates)
    {
        // Check if commission is still active.
        CommissionedInfo storage commissionedInfo_ = commissionedInfo[commissioned];
        bool active = block.timestamp > commissionedInfo_.validUntil ? false : true;

        // If not active, return empty arrays
        if (active == true) {
            // Return recipients and rates for specific commission group.
            CommissionGroupInfo storage groupInfo = commissionGroupInfo[commissionedInfo_.groupId];
            recipients = groupInfo.recipients;
            rates = groupInfo.rates;
        }
    }

    function getCommissionGroupInfo(uint256 groupId) external view returns (address[] memory, uint256[] memory) {
        CommissionGroupInfo storage info = commissionGroupInfo[groupId];
        return (info.recipients, info.rates);
    }
}
