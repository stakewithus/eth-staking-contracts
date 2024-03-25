// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {IEigenStaking} from "src/interfaces/IEigenStaking.sol";
import {EigenStaking} from "src/eigenlayer/EigenStaking.sol";

contract EigenStakingIntegrationTest is Test {
    function setUp() public {
        // TODO: Move to holesky/mainnet once deployed
        vm.createSelectFork(vm.envString("RPC_GOERLI"), vm.envUint("FORK_BLOCK_NUMBER"));
    }
}
