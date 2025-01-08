// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IBridge} from "arbitrum-nitro-contracts/bridge/IBridge.sol";
import {IInbox} from "arbitrum-nitro-contracts/bridge/IInbox.sol";
import {IOutbox} from "arbitrum-nitro-contracts/bridge/IOutbox.sol";
import {ArbSys} from "arbitrum-nitro-contracts/precompiles/ArbSys.sol";

import {KeystoreBridgeStorageLib} from "../state/KeystoreBridgeStorageLib.sol";

import {L2ToL1MsgSenderIsNotThisContract, L2ToL1TxSenderIsNotRollupContract} from "./PortalErrors.sol";
import {ReceiverAliasedAddress} from "./ReceiverAliasedAddress.sol";

contract KeystoreArbitrumPortal is ReceiverAliasedAddress {
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                           CONSTANTS                                            //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Address of the Arbitrum `Inbox` contract on L1.
    address constant ARBITRUM_INBOX = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;

    /// @notice Address of the `ArbSys` contract on Arbitrum.
    address constant ARBSYS = 0x0000000000000000000000000000000000000064;

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                        PUBLIC FUNCTIONS                                        //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Sends the root to Arbitrum.
    ///
    /// @param chainid The chain id key to look up the root to send. If `chainid` is 0, the local root is sent.
    /// @param maxSubmissionCost The maximum cost of submitting the retryable ticket.
    /// @param gasLimit The gas limit for the retryable ticket on L2.
    /// @param maxFeePerGas The maximum fee per gas for the retryable ticket.
    function sendToArbitrum(uint256 chainid, uint256 maxSubmissionCost, uint256 gasLimit, uint256 maxFeePerGas)
        external
    {
        (uint256 originChainid, bytes32 root) = chainid == 0
            ? (block.chainid, KeystoreBridgeStorageLib.localRoot())
            : (chainid, KeystoreBridgeStorageLib.receivedRoot(chainid));

        // TODO: Make it work with Arbitrum L3s.
        IInbox(ARBITRUM_INBOX).createRetryableTicket({
            to: address(this),
            l2CallValue: 0,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: msg.sender,
            callValueRefundAddress: msg.sender,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            data: abi.encodeCall(ReceiverAliasedAddress.receiveFromAliasedAddress, (originChainid, root))
        });
    }

    /// @notice Sends the local root back to L1.
    ///
    /// @dev Only withdrawals from Arbitrum (and not its L3s) are supported as the targeted `receiveOnL1FromArbitrum`
    ///      method only works on L1.
    /// @dev This method does not accept a `chainid` as "withdrawals" to L1 should only ever use the local root (and not
    ///      a received one).
    function sendFromArbitrumToL1() external {
        ArbSys(ARBSYS).sendTxToL1({
            destination: address(this),
            data: abi.encodeCall(
                KeystoreArbitrumPortal.receiveOnL1FromArbitrum, (block.chainid, KeystoreBridgeStorageLib.localRoot())
            )
        });
    }

    /// @notice Receives a root sent from Arbitrum.
    ///
    /// @param originChainid The origin chain id.
    /// @param root The root being received.
    function receiveOnL1FromArbitrum(uint256 originChainid, bytes32 root) external {
        // Ensure the tx sender is the Arbitrum Bridge contract.
        IBridge bridge = IInbox(ARBITRUM_INBOX).bridge();
        require(msg.sender == address(bridge), L2ToL1TxSenderIsNotRollupContract());

        // Ensure the message originates from this contract.
        IOutbox outbox = IOutbox(bridge.activeOutbox());
        require(outbox.l2ToL1Sender() == address(this), L2ToL1MsgSenderIsNotThisContract());

        // Register the root.
        KeystoreBridgeStorageLib.sKeystoreBridge().receivedRoots[originChainid] = root;
    }
}
