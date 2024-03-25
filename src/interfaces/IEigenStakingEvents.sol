// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IEigenStakingEvents {
    event UserRegistered(address indexed user, address indexed eigenUser);
    event Deposit(address indexed from, address indexed user, uint256 validators);
    event Staked(address indexed user, bytes[] pubkeys);
    event Refund(address indexed user, uint256 validators);
    event OneTimeFeeSet(uint256);
    event PerformanceFeeSet(uint256);
    event NewTreasury(address indexed oldTreasury, address indexed newTreasury);
    event RefundDelaySet(uint256);
}
