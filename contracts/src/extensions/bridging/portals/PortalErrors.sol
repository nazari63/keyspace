// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @notice Thrown when the sender of a L2-to-L1 transaction is not the expected rollup contract.
error L2ToL1TxSenderIsNotRollupContract();

/// @notice Thrown when the sender of a L2-to-L1 message is not this contract.
error L2ToL1MsgSenderIsNotThisContract();

/// @notice Thrown when the sender of a parent-to-child chainmessage is not this contract.
error MsgSenderFromParentChainIsNotThisContract();
