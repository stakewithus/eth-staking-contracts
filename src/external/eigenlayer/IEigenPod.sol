// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

// https://github.com/Layr-Labs/eigenlayer-contracts/blob/testnet-goerli/src/contracts/interfaces/IEigenPod.sol

interface IEigenPod {
    /// https://github.com/Layr-Labs/eigenlayer-contracts/blob/testnet-goerli/src/contracts/libraries/BeaconChainProofs.sol#L133
    struct StateRootProof {
        bytes32 beaconStateRoot;
        bytes proof;
    }
    /**
     * @notice This function verifies that the withdrawal credentials of validator(s) owned by the podOwner are pointed to
     * this contract. It also verifies the effective balance  of the validator.  It verifies the provided proof of the ETH validator against the beacon chain state
     * root, marks the validator as 'active' in EigenLayer, and credits the restaked ETH in Eigenlayer.
     * @param oracleTimestamp is the Beacon Chain timestamp whose state root the `proof` will be proven against.
     * @param validatorIndices is the list of indices of the validators being proven, refer to consensus specs
     * @param withdrawalCredentialProofs is an array of proofs, where each proof proves each ETH validator's balance and withdrawal credentials
     * against a beacon chain state root
     * @param validatorFields are the fields of the "Validator Container", refer to consensus specs
     * for details: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyWithdrawalCredentials(
        uint64 oracleTimestamp,
        StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata withdrawalCredentialProofs,
        bytes32[][] calldata validatorFields
    ) external;
}
