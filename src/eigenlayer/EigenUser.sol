// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import {IEigenPod} from "src/external/eigenlayer/IEigenPod.sol";
import {IEigenPodManager} from "src/external/eigenlayer/IEigenPodManager.sol";
import {StakingConstants} from "src/StakingConstants.sol";
import {IEigenStaking} from "src/interfaces/IEigenStaking.sol";

contract EigenUser is StakingConstants {
    IEigenStaking public immutable staking;
    address public immutable user;

    IEigenPodManager public immutable eigenPodManager; // is this immutable?
    IEigenPod public immutable eigenPod;

    error Unauthorized();

    constructor(address user_, address eigenPodManager_) {
        staking = IEigenStaking(payable(msg.sender));
        user = user_;
        eigenPodManager = IEigenPodManager(eigenPodManager_);
        eigenPod = IEigenPod(eigenPodManager.createPod()); // necessary?
    }

    function stake(IEigenStaking.DepositData[] memory data_) external payable onlyStaking {
        // how to handle multiple deposits?

        // stake needs to be called from this contract as EigenPod defaults to msg.sender's

        uint8 length = uint8(data_.length);
        for (uint8 i = 0; i < length; i++) {
            eigenPodManager.stake{value: 32 ether}(data_[i].pubkey, data_[i].signature, data_[i].deposit_data_root);
        }

        // TODO: events? or let staking handle
    }

    function delegateTo(address operator_) external onlyUser {}

    function undelegate() external onlyUser {}

    modifier onlyUser() {
        if (msg.sender != user) revert Unauthorized();
        _;
    }

    modifier onlyStaking() {
        if (msg.sender != address(staking)) revert Unauthorized();
        _;
    }
}
