// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IStaking {
    struct DepositData {
        bytes pubkey;
        bytes signature;
        bytes32 deposit_data_root;
    }

    event UserRegistered(address indexed user, address indexed feeRecipient);
    event Deposit(address indexed from, address indexed user, uint256 validators);
    event Staked(address indexed user, bytes[] pubkeys);
    event Refund(address indexed user, uint256 validators);
    event OneTimeFeeSet(uint256);
    event PerformanceFeeSet(uint256);
    event NewTreasury(address indexed oldTreasury, address indexed newTreasury);
    event RefundDelaySet(uint256);

    function depositContract() external view returns (address);

    function treasury() external view returns (address);

    function oneTimeFee() external view returns (uint256);

    function performanceFee() external view returns (uint256);

    function registry(address) external view returns (address);

    function pendingValidators(address) external view returns (uint256);

    function deposit(address user) external payable;
}
