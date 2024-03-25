// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

interface IEigenStaking {
    struct DepositData {
        bytes pubkey;
        bytes signature;
        bytes32 deposit_data_root;
    }
}
