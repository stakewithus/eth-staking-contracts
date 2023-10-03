// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {IStaking} from "src/interfaces/IStaking.sol";
import {Staking} from "src/Staking.sol";

contract StakingIntegrationTest is Test {
    Staking staking;

    address user = address(0x0a1F3A2c20a7e8E4470fFA52c01646E1ff4c759A);
    address treasury = address(2);
    address deposit = address(0x00000000219ab540356cBB839Cbe05303d7705Fa);

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_MAINNET"), vm.envUint("FORK_BLOCK_NUMBER"));

        staking = new Staking(address(this), address(this), deposit, treasury, 1 ether, 100, 0);
        vm.deal(address(this), type(uint128).max);
        staking.deposit{value: 33 ether}(user);
    }

    event Staked(address indexed user, bytes[] pubkeys);

    function test_stake() public {
        IStaking.DepositData[] memory data = new IStaking.DepositData[](1);

        bytes
            memory pubkey = hex"a6fff6268e249dc9979cb9c4387dc160f7b1b29a63593530ad93bb8750c926da729ebe397e089ec1d402bb9e97bfac1e";

        data[0] = (
            IStaking.DepositData({
                pubkey: pubkey,
                signature: hex"8c60f8b0803c14765713d31e9ee7d8e96a89a701e3f873d5e86ccb5abe4e42458e3a7a7191f3dcd59aaa4a009c173a9c18a8adb8f3e2d5f93c20a46d8130edbf2300026dd3d7d5ade02f2ab05b1f6012f1d38bfb571938a4cad26edc2d1bc443",
                deposit_data_root: 0x4525556dd4fd2884bd88bf9d40c7dad4fec21bb0c5842a6e3fc3cc0889d4c314
            })
        );

        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = pubkey;

        vm.expectEmit();
        emit Staked(user, pubkeys);
        staking.stake(user, data);
    }
}
