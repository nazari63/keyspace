// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {BinaryMerkleTreeLib} from "./BinaryMerkleTreeLib.sol";

library KeystoreBridgeStorageLib {
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                           CONSTANTS                                            //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Slot for the `KeystoreBridgeStorage` struct in storage.
    ///
    /// @dev Computed as specified in ERC-7201 (see https://eips.ethereum.org/EIPS/eip-7201):
    ///      keccak256(abi.encode(uint256(keccak256("storage.KeystoreBridge")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant KEYSTORE_BRIDGE_STORAGE_LOCATION =
        0xdc1385528a9b908c68acf3182ab1264a2e9196d0ad7796b3195cec20a6fd9000;

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                            STRUCTURES                                          //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Storage layout of the Keystore bridge.
    ///
    /// @custom:storage-location erc7201:storage.KeystoreBridge
    struct KeystoreBridgeStorage {
        /// @dev The latest received root per origin chain id.
        mapping(uint256 originChainid => bytes32 receivedRoot) receivedRoots;
        /// @dev The local Merkle tree of Keystore configs.
        BinaryMerkleTreeLib.Tree _tree;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                        INTERNAL FUNCTIONS                                      //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Helper function to get a storage reference to the `KeystoreBridgeStorage` struct.
    ///
    /// @dev This function is unsafe as it gives unlimited access to the `KeystoreBridgeStorage` struct. It should be
    ///      used with caution.
    ///
    /// @return $ A storage reference to the `KeystoreBridgeStorage` struct.
    function sKeystoreBridge() internal pure returns (KeystoreBridgeStorage storage $) {
        bytes32 position = KEYSTORE_BRIDGE_STORAGE_LOCATION;
        assembly ("memory-safe") {
            $.slot := position
        }
    }

    /// @notice Returns the received root for a given origin chain id.
    ///
    /// @param originChainid The origin chain id.
    ///
    /// @return The received root.
    function receivedRoot(uint256 originChainid) internal view returns (bytes32) {
        return sKeystoreBridge().receivedRoots[originChainid];
    }

    /// @notice Returns the local root.
    ///
    /// @return The local root.
    function localRoot() internal view returns (bytes32) {
        BinaryMerkleTreeLib.Tree storage tree = sKeystoreBridge()._tree;
        return BinaryMerkleTreeLib.root(tree);
    }
}
