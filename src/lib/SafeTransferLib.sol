// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

/// @notice Gas-efficient safe ETH transfer library that gracefully handles missing return values.
/// @author Copied from Solmate with ERC20 code removed.
/// @author https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }
}
