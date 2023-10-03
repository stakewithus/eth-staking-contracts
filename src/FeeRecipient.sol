// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IStaking} from "src/interfaces/IStaking.sol";
import {SafeTransferLib} from "src/lib/SafeTransferLib.sol";
import {StakingConstants} from "src/StakingConstants.sol";

/**
 * @notice Contract set as the `fee_recipient` for all validators belonging to a user. Receives execution layer rewards
 * from block production gas tips and MEV bribes which users can claim via `claimRewards()` function.
 */
contract FeeRecipient is StakingConstants {
    using FixedPointMathLib for uint256;

    IStaking public immutable staking;
    address public immutable user;

    /// @dev Unclaimed rewards that fully belong to user.
    uint256 internal _userRewards;

    error Unauthorized();

    constructor(address user_) {
        staking = IStaking(payable(msg.sender));
        user = user_;
    }

    /// @dev To receive MEV bribes directly transferred to `fee_recipient`.
    receive() external payable {}

    function unclaimedRewards() external view returns (uint256) {
        return address(this).balance - _calcToTreasury(address(this).balance - _userRewards);
    }

    function claimRewards() external onlyUser {
        _treasuryClaim();

        SafeTransferLib.safeTransferETH(user, address(this).balance);

        _userRewards = 0;
    }

    function treasuryClaim() external onlyTreasury {
        _treasuryClaim();
    }

    function _treasuryClaim() internal {
        uint256 share = address(this).balance - _userRewards;
        uint256 toTreasury = _calcToTreasury(share);
        if (toTreasury == 0) return; // Do nothing as treasury has nothing to claim.

        _userRewards += share - toTreasury;

        SafeTransferLib.safeTransferETH(staking.treasury(), toTreasury);
    }

    function _calcToTreasury(uint256 amount_) internal view returns (uint256) {
        return amount_.mulDivDown(staking.performanceFee(), FEE_BASIS);
    }

    modifier onlyUser() {
        if (msg.sender != user) revert Unauthorized();
        _;
    }

    modifier onlyTreasury() {
        if (msg.sender != staking.treasury()) revert Unauthorized();
        _;
    }
}
