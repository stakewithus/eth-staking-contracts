// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IDepositContract} from "src/interfaces/IDepositContract.sol";
import {IStaking} from "src/interfaces/IStaking.sol";
import {Owned} from "src/lib/Owned.sol";
import {Pausable} from "src/lib/Pausable.sol";
import {SafeTransferLib} from "src/lib/SafeTransferLib.sol";
import {FeeRecipient} from "src/FeeRecipient.sol";
import {StakingConstants} from "src/StakingConstants.sol";

contract Staking is IStaking, ReentrancyGuard, Owned, Pausable, StakingConstants {
    /// @notice Ethereum staking deposit contract address.
    address public immutable depositContract;
    /// @notice Unagii treasury which receives share of profit from execution layer rewards.
    address public treasury;
    /// @notice One-time fee for creating a new validator.
    uint256 public oneTimeFee;
    /// @notice Performance fee percentage from execution layer rewards / `FEE_BASIS`, i.e. 10_000 represents 100%.
    uint256 public performanceFee;
    /// @notice Delay before a user can initiate a refund of pending unstaked ETH.
    uint256 public refundDelay;
    /// @notice Total number pending unstaked deposits across all users.
    uint256 public totalPendingValidators;

    /// @notice Mapping of users to FeeRecipient contracts which users collect their execution layer rewards from.
    mapping(address => address) public registry;
    /// @notice Mapping of users to number of pending unstaked deposits for that user.
    mapping(address => uint256) public pendingValidators;
    /// @notice Mapping of users to timestamp of their last deposit.
    mapping(address => uint256) public lastDepositTimestamp;

    uint256 internal constant _DEPOSIT_AMOUNT = 32 ether;
    uint256 internal constant _MAXIMUM_REFUND_DELAY = 7 days;

    error InvalidAmount();
    error InvalidLength();
    error PendingValidators();
    error NoDeposit();
    error BeforeRefundDelay();
    error SameValue();

    constructor(
        address owner_,
        address operator_,
        address depositContract_,
        address treasury_,
        uint256 oneTimeFee_,
        uint256 performanceFee_,
        uint256 refundDelay_
    ) Owned(owner_, operator_) {
        if (depositContract_ == address(0)) revert ZeroAddress();
        depositContract = depositContract_;
        _setTreasury(treasury_);
        _setOneTimeFee(oneTimeFee_);
        _setPerformanceFee(performanceFee_);
        _setRefundDelay(refundDelay_);
    }

    /// @dev Costs less gas than `deposit()` if user if depositing for their own address.
    receive() external payable {
        _deposit(msg.sender);
    }

    /*//////////////////////////////////////
	            PUBLIC FUNCTIONS
	//////////////////////////////////////*/

    /**
     * @notice Deposits ETH into this contract for Unagii to create a new validator node on user's behalf.
     * @param user_ User's withdrawal address which receives consensus rewards and can claim execution layer rewards.
     * @dev `msg.value` must be a multiple of `_DEPOSIT_AMOUNT (32 ether) + oneTimeFee`
     */
    function deposit(address user_) external payable {
        _deposit(user_);
    }

    function _deposit(address user_) internal whenNotPaused nonReentrant {
        if (user_ == address(0)) revert ZeroAddress();
        if (pendingValidators[user_] > 0) revert PendingValidators();

        uint256 perValidator = _DEPOSIT_AMOUNT + oneTimeFee;
        if (msg.value == 0 || msg.value % perValidator != 0) revert InvalidAmount();

        // Deploy FeeRecipient for address if its their first deposit.
        if (registry[user_] == address(0)) {
            address feeRecipient = address(new FeeRecipient(user_));
            registry[user_] = feeRecipient;
            emit UserRegistered(user_, feeRecipient);
        }

        uint256 validators = msg.value / perValidator;

        pendingValidators[user_] += validators;
        totalPendingValidators += validators;
        lastDepositTimestamp[user_] = block.timestamp;

        emit Deposit(msg.sender, user_, validators);
    }

    /**
     * @notice Refunds unstaked ETH to user. User must wait for at least `refundDelay` after depositing before
     * initiating a refund.
     */
    function refund() external nonReentrant {
        uint256 validators = pendingValidators[msg.sender];
        if (block.timestamp < lastDepositTimestamp[msg.sender] + refundDelay) revert BeforeRefundDelay();

        _refund(msg.sender, validators);
    }

    /*////////////////////////////////////////
	            OPERATOR FUNCTIONS
	////////////////////////////////////////*/

    function stake(address user_, DepositData[] memory data_) external onlyOperator {
        uint256 length = data_.length;
        if (length == 0) revert InvalidLength();

        // This underflows, throwing an error if length > pendingValidators[user_]
        pendingValidators[user_] -= length;
        totalPendingValidators -= length;

        if (oneTimeFee > 0) SafeTransferLib.safeTransferETH(treasury, length * oneTimeFee);

        bytes[] memory pubkeys = new bytes[](length);

        for (uint256 i = 0; i < length; ++i) {
            bytes memory pubkey = data_[i].pubkey;

            IDepositContract(depositContract).deposit{value: _DEPOSIT_AMOUNT}({
                pubkey: pubkey,
                withdrawal_credentials: abi.encodePacked(true, uint88(0), user_), // true | 11 bytes padding | address
                signature: data_[i].signature,
                deposit_data_root: data_[i].deposit_data_root
            });

            pubkeys[i] = pubkey;
        }

        emit Staked(user_, pubkeys);
    }

    function refundUser(address user_, uint256 validators_) external onlyOperator {
        _refund(user_, validators_);
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    /*/////////////////////////////////////
	            OWNER FUNCTIONS
	/////////////////////////////////////*/

    function setOneTimeFee(uint256 oneTimeFee_) external onlyOwner {
        if (oneTimeFee_ == oneTimeFee) revert SameValue();
        _setOneTimeFee(oneTimeFee_);
    }

    function setPerformanceFee(uint256 performanceFee_) external onlyOwner {
        if (performanceFee_ == performanceFee) revert SameValue();
        _setPerformanceFee(performanceFee_);
    }

    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert ZeroAddress();
        if (treasury_ == treasury) revert SameValue();
        _setTreasury(treasury_);
    }

    function setRefundDelay(uint256 refundDelay_) external onlyOwner {
        if (refundDelay_ == refundDelay) revert SameValue();
        _setRefundDelay(refundDelay_);
    }

    /*////////////////////////////////////////
	            INTERNAL FUNCTIONS
	////////////////////////////////////////*/

    function _refund(address user_, uint256 validators_) internal {
        if (validators_ == 0) revert NoDeposit();

        // This underflows, throwing an error if validators_ > pendingValidators[user_]
        pendingValidators[user_] -= validators_;
        totalPendingValidators -= validators_;

        SafeTransferLib.safeTransferETH(user_, validators_ * (_DEPOSIT_AMOUNT + oneTimeFee));
        emit Refund(user_, validators_);
    }

    /// @dev One-time fee cannot be adjusted while there are still pending validators. Pause contract and stake/refund
    /// all pending validators before changing one-time fee.
    function _setOneTimeFee(uint256 oneTimeFee_) internal {
        if (totalPendingValidators != 0) revert PendingValidators();
        oneTimeFee = oneTimeFee_;
        emit OneTimeFeeSet(oneTimeFee_);
    }

    function _setPerformanceFee(uint256 performanceFee_) internal {
        if (performanceFee_ > FEE_BASIS) revert InvalidAmount();
        performanceFee = performanceFee_;
        emit PerformanceFeeSet(performanceFee_);
    }

    function _setTreasury(address treasury_) internal {
        emit NewTreasury(treasury, treasury_);
        treasury = treasury_;
    }

    function _setRefundDelay(uint256 refundDelay_) internal {
        if (refundDelay_ > _MAXIMUM_REFUND_DELAY) revert InvalidAmount();
        refundDelay = refundDelay_;
        emit RefundDelaySet(refundDelay_);
    }
}
