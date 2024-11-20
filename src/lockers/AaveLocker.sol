// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AbstractLocker} from "./AbstractLocker.sol";
import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";
import {IAaveToken} from "./interfaces/IAaveToken.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveV3Locker is AbstractLocker {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;
    /* //////////////////////////////////////////////////////////////
                              CONSTANTS
    ////////////////////////////////////////////////////////////// */

    IAavePool internal immutable AAVE_POOL;
    IAaveToken internal immutable ATOKEN;

    /* //////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor(address owner_, address aToken, address aavePool) AbstractLocker(owner_) {
        ATOKEN = IAaveToken(aToken);
        AAVE_POOL = IAavePool(aavePool);
    }

    /* //////////////////////////////////////////////////////////////
                              AAVE LOGIC
    ////////////////////////////////////////////////////////////// */

    function deposit(address asset, uint256 amount) external override onlyOwner {
        // Increase amount deposited.
        totalDeposited += amount;

        // Deposit asset in pool.
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(AAVE_POOL), amount);
        AAVE_POOL.supply(asset, amount, address(this), 0);
    }

    function withdraw(address asset, uint256 amount) external override onlyOwner {
        // Decrease amount deposited.
        totalDeposited -= amount;

        // Withdraw asset from pool to the owner.
        AAVE_POOL.withdraw(asset, amount, msg.sender);
    }

    function collectYield(address asset) external override onlyOwner returns (uint256 yield) {
        // Calculate current value of position in underlying token.
        uint256 withdrawableBalance = getTotalValue(asset);

        // The yield is the difference between current claimable balance and total deposited.
        // Cache value
        uint256 totalDeposited_ = totalDeposited;
        yield = withdrawableBalance > totalDeposited_ ? withdrawableBalance - totalDeposited_ : 0;

        // Withdraw asset from pool to the owner.
        // Yield is updated in case the final withdrawn amount differs.
        yield = AAVE_POOL.withdraw(asset, yield, msg.sender);
    }

    function getTotalValue(address asset) public view override returns (uint256 value) {
        // Calculate current value of position in underlying token.
        uint256 aTokenScaledBalance = ATOKEN.scaledBalanceOf(address(this));
        uint256 liquidityIndex = AAVE_POOL.getReserveNormalizedIncome(asset);
        value = aTokenScaledBalance.mulDivDown(liquidityIndex, 1e27);
    }

    function fullWithdraw(address asset) external override onlyOwner returns (uint256 principal, uint256 yield) {
        // Calculate current value of position in underlying token.
        uint256 withdrawableBalance = getTotalValue(asset);

        // Cache value
        uint256 totalDeposited_ = totalDeposited;
        totalDeposited = 0;

        // The yield is the difference between current claimable balance and total deposited.
        yield = withdrawableBalance > totalDeposited_ ? withdrawableBalance - totalDeposited_ : 0;

        uint256 totalWithdrawn = AAVE_POOL.withdraw(asset, type(uint256).max, msg.sender);
        principal = totalWithdrawn - yield;
    }
}
