// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Staking} from "src/Staking.sol";
import {FeeRecipient} from "src/FeeRecipient.sol";

contract FeeRecipientTest is Test {
    Staking staking;
    FeeRecipient feeRecipient;

    address user = address(1);
    address treasury = address(2);
    address deposit = address(3);

    function setUp() public {
        staking = new Staking(address(this), address(this), deposit, treasury, 0, 100, 0);
        vm.deal(address(this), type(uint128).max);
        staking.deposit{value: 32 ether}(user);
        feeRecipient = FeeRecipient(payable(staking.registry(user)));
    }

    function test_claimRewards(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint248).max);
        vm.deal(address(feeRecipient), amount_);

        uint256 userBalance = user.balance;

        uint256 toTreasury = (amount_ * 100) / 10_000;
        uint256 toUser = amount_ - toTreasury;

        assertEq(toUser, feeRecipient.unclaimedRewards());

        vm.prank(user);
        feeRecipient.claimRewards();

        assertEq(treasury.balance, toTreasury);
        assertEq(user.balance, userBalance + toUser);
        assertEq(feeRecipient.unclaimedRewards(), 0);
    }

    function test_treasuryClaim(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint248).max);
        vm.deal(address(feeRecipient), amount_);

        uint256 userBalance = user.balance;

        uint256 toTreasury = (amount_ * 100) / 10_000;
        uint256 toUser = amount_ - toTreasury;

        assertEq(toUser, feeRecipient.unclaimedRewards());

        vm.prank(treasury);
        feeRecipient.treasuryClaim();

        assertEq(toUser, feeRecipient.unclaimedRewards());

        vm.prank(user);
        feeRecipient.claimRewards();

        assertEq(treasury.balance, toTreasury);
        assertEq(user.balance, userBalance + toUser);
        assertEq(feeRecipient.unclaimedRewards(), 0);
    }
}
