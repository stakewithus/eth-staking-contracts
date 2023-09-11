// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

/// @notice Contract for shared values between Staking.sol and FeeRecipient.sol.
abstract contract StakingConstants {
    /// @notice Denominator for calculating performance fees, i.e. a `performanceFee` of 10_000 represents 100%.
    uint256 public constant FEE_BASIS = 10_000;
}
