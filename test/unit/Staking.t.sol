// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Staking} from "src/Staking.sol";
import {IDepositContract} from "src/interfaces/IDepositContract.sol";
import {IStaking} from "src/interfaces/IStaking.sol";
import {Owned} from "src/lib/Owned.sol";
import {Pausable} from "src/lib/Pausable.sol";
import {FeeRecipient} from "src/FeeRecipient.sol";

contract MockDepositContract is IDepositContract {
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable {}
}

contract StakingTest is Test {
    Staking staking;
    MockDepositContract deposit;

    address user = address(1);
    address treasury = address(2);

    function setUp() public {
        deposit = new MockDepositContract();
        staking = new Staking(address(this), address(this), address(deposit), treasury, 1 ether, 100, 0);
        vm.deal(user, type(uint248).max);
    }

    event UserRegistered(address indexed user, address indexed feeRecipient);
    event Deposit(address indexed from, address indexed user, uint256 validators);
    event Refund(address indexed user, uint256 validators);

    function test_deposit(uint8 validators_) public {
        vm.assume(validators_ > 0 && validators_ < 140);

        assertEq(staking.pendingValidators(user), 0);
        assertEq(staking.registry(user), address(0));

        vm.expectEmit(true, false, false, false);
        emit UserRegistered(user, address(0));
        vm.expectEmit();
        emit Deposit(user, user, validators_);
        vm.prank(user);
        staking.deposit{value: validators_ * 33 ether}(user);

        assertEq(staking.pendingValidators(user), validators_);
        assertEq(address(staking).balance, validators_ * 33 ether);

        // Fee recipient was updated from address(0) to deployed contract.
        address payable feeRecipient = payable(staking.registry(user));
        assertTrue(feeRecipient != address(0));
        assertEq(FeeRecipient(feeRecipient).user(), user);

        // Subsequent deposit reverts as user has pending validators.
        vm.expectRevert(Staking.PendingValidators.selector);
        vm.prank(user);
        staking.deposit{value: 33 ether}(user);

        vm.prank(user);
        staking.refund();

        assertEq(staking.pendingValidators(user), 0);

        // User can deposit again if pending validators == 0.
        vm.expectEmit();
        emit Deposit(user, user, validators_);
        vm.prank(user);
        staking.deposit{value: validators_ * 33 ether}(user);

        // Fee recipient did not change on subsequent deposit.
        assertEq(feeRecipient, staking.registry(user));
    }

    function test_receive(uint8 validators_) public {
        vm.assume(validators_ > 0 && validators_ < 100);

        assertEq(staking.pendingValidators(user), 0);
        assertEq(staking.registry(user), address(0));

        vm.expectEmit(true, false, false, false);
        emit UserRegistered(user, address(0));
        vm.expectEmit();
        emit Deposit(user, user, validators_);
        vm.prank(user);
        (bool success, ) = address(staking).call{value: validators_ * 33 ether}("");
        assertTrue(success);

        assertEq(staking.pendingValidators(user), validators_);
        assertEq(address(staking).balance, validators_ * 33 ether);
    }

    function test_deposit_reverts_if_zero_address() public {
        vm.expectRevert(Owned.ZeroAddress.selector);
        staking.deposit{value: 33 ether}(address(0));
    }

    function test_deposit_reverts_on_invalid_amount(uint256 amount_) public {
        vm.assume(amount_ % 33 ether != 0 && amount_ < type(uint240).max);
        vm.expectRevert(Staking.InvalidAmount.selector);
        vm.prank(user);
        staking.deposit{value: amount_}(user);
    }

    function test_deposit_reverts_when_paused() public {
        staking.pause();

        vm.expectRevert(Pausable.IsPaused.selector);
        vm.prank(user);
        staking.deposit{value: 33 ether}(user);
    }

    function test_refund(uint8 validators_, uint256 oneTimeFee_) public {
        vm.assume(validators_ > 0 && validators_ < 140);
        vm.assume(oneTimeFee_ < 1 ether);

        staking.setOneTimeFee(oneTimeFee_);

        uint256 balance = address(user).balance;

        vm.prank(user);
        staking.deposit{value: validators_ * (32 ether + oneTimeFee_)}(user);
        vm.expectEmit();
        emit Refund(user, validators_);
        vm.prank(user);
        staking.refund();

        assertEq(balance, address(user).balance);
    }

    function test_refund_reverts_before_refund_delay() public {
        staking.setRefundDelay(3 days);

        uint256 balance = address(user).balance;

        vm.prank(user);
        staking.deposit{value: 33 ether}(user);
        vm.expectRevert(Staking.BeforeRefundDelay.selector);
        vm.prank(user);
        staking.refund();

        assertEq(address(user).balance, balance - 33 ether);

        vm.warp(3 days + 1);
        vm.prank(user);
        staking.refund();

        assertEq(address(user).balance, balance);
    }

    function test_refund_reverts_if_no_pending_validators() public {
        vm.expectRevert(Staking.NoDeposit.selector);
        vm.prank(user);
        staking.refund();

        vm.prank(user);
        staking.deposit{value: 33 ether}(user);

        vm.expectRevert(Staking.NoDeposit.selector);
        staking.refundUser(user, 0);
    }

    function test_stake_reverts_if_invalid_length() public {
        vm.prank(user);
        staking.deposit{value: 33 ether}(user);

        IStaking.DepositData[] memory data = new IStaking.DepositData[](0);

        vm.expectRevert(Staking.InvalidLength.selector);
        staking.stake(user, data);

        data = new IStaking.DepositData[](2);

        bytes32 root = "0";

        data[0] = IStaking.DepositData({pubkey: hex"00", signature: hex"00", deposit_data_root: root});
        data[1] = IStaking.DepositData({pubkey: hex"ff", signature: hex"ff", deposit_data_root: root});

        vm.expectRevert();
        staking.stake(user, data);
    }

    event OneTimeFeeSet(uint256);

    function test_setOneTimeFee_reverts_if_there_are_pending_validators() public {
        assertEq(staking.oneTimeFee(), 1 ether);

        vm.prank(user);
        staking.deposit{value: 33 ether}(user);

        assertGt(staking.totalPendingValidators(), 0);

        vm.expectRevert(Staking.PendingValidators.selector);
        staking.setOneTimeFee(2 ether);

        assertEq(staking.oneTimeFee(), 1 ether);

        staking.refundUser(user, 1);

        assertEq(staking.totalPendingValidators(), 0);

        vm.expectEmit();
        emit OneTimeFeeSet(2 ether);
        staking.setOneTimeFee(2 ether);

        assertEq(staking.oneTimeFee(), 2 ether);
    }

    function test_setRefundDelay_cannot_exceed_maximum(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint240).max);

        vm.expectRevert(Staking.InvalidAmount.selector);
        staking.setRefundDelay(7 days + amount_);
    }

    function test_setPerformanceFee_cannot_exceed_maximum(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint240).max);

        vm.expectRevert(Staking.InvalidAmount.selector);
        staking.setPerformanceFee(10_000 + amount_);
    }
}
