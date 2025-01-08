// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {AddressAliasHelper} from "optimism-contracts/vendor/AddressAliasHelper.sol";

import {KeystoreBridgeStorageLib} from "../state/KeystoreBridgeStorageLib.sol";

import {MsgSenderFromParentChainIsNotThisContract} from "./PortalErrors.sol";

contract ReceiverAliasedAddress {
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                        PUBLIC FUNCTIONS                                        //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Receives a root sent from this contract aliased address.
    ///
    /// @param originChainid The origin chain id.
    /// @param root The root being received.
    function receiveFromAliasedAddress(uint256 originChainid, bytes32 root) external {
        // Ensure the `msg.sender` is the aliased address of this contract.
        require(
            AddressAliasHelper.undoL1ToL2Alias(msg.sender) == address(this), MsgSenderFromParentChainIsNotThisContract()
        );

        // Register the root.
        KeystoreBridgeStorageLib.sKeystoreBridge().receivedRoots[originChainid] = root;
    }
}
