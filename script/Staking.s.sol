// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import "forge-std/Script.sol";
import "src/Staking.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        new Staking({
            owner_: vm.envAddress("OWNER"),
            operator_: vm.envAddress("OPERATOR"),
            depositContract_: _depositContract(),
            treasury_: vm.envAddress("TREASURY"),
            oneTimeFee_: 1e17, // 0.1 ether
            performanceFee_: 100, // 10%
            refundDelay_: 3 days
        });

        vm.stopBroadcast();
    }

    function _depositContract() internal view returns (address) {
        if (block.chainid == 1) return 0x00000000219ab540356cBB839Cbe05303d7705Fa;
        else if (block.chainid == 5) return 0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b;
        else revert("Unsupported chain.");
    }
}
