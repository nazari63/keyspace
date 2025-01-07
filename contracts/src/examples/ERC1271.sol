// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ERC-1271
///
/// @notice Abstract ERC-1271 implementation (based on Solady's) with guards to handle the same
///         signer being used on multiple accounts.
///
/// @dev To prevent the same signature from being validated on different accounts owned by the samer signer,
///      we introduce an anti cross-account-replay layer: the original hash is input into a new EIP-712 compliant
///      hash. The domain separator of this outer hash contains the chain id and address of this contract, so that
///      it cannot be used on two accounts (see `replaySafeHash()` for the implementation details).
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/accounts/ERC1271.sol)
abstract contract ERC1271 {
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                           CONSTANTS                                            //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Precomputed `typeHash` to produce EIP-712 compliant hash when applying the anti cross-account-replay layer.
    ///
    ///      The original hash must either be:
    ///         - An EIP-191 hash: keccak256("\x19Ethereum Signed Message:\n" || len(someMessage) || someMessage)
    ///         - An EIP-712 hash: keccak256("\x19\x01" || someDomainSeparator || hashStruct(someStruct))
    bytes32 private constant _MESSAGE_TYPEHASH = keccak256("ReplaySafeHashWrapper(bytes32 hash)");

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                        PUBLIC FUNCTIONS                                        //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Returns information about the `EIP712Domain` used to create EIP-712 compliant hashes.
    ///
    /// @dev Follows ERC-5267 (see https://eips.ethereum.org/EIPS/eip-5267).
    ///
    /// @return fields The bitmap of used fields.
    /// @return name The value of the `EIP712Domain.name` field.
    /// @return version The value of the `EIP712Domain.version` field.
    /// @return chainId The value of the `EIP712Domain.chainId` field.
    /// @return verifyingContract The value of the `EIP712Domain.verifyingContract` field.
    /// @return salt The value of the `EIP712Domain.salt` field.
    /// @return extensions The list of EIP numbers, that extends EIP-712 with new domain fields.
    function eip712Domain()
        external
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        fields = hex"0f"; // `0b1111`.
        (name, version) = _domainNameAndVersion();
        chainId = block.chainid;
        verifyingContract = address(this);
        salt = salt; // `bytes32(0)`.
        extensions = extensions; // `new uint256[](0)`.
    }

    /// @notice Validates the `signature` against the given `hash`.
    ///
    /// @dev This implementation follows ERC-1271. See https://eips.ethereum.org/EIPS/eip-1271.
    /// @dev IMPORTANT: Signature verification is performed on the hash produced AFTER applying the anti
    ///      cross-account-replay layer on the given `hash` (i.e., verification is run on the replay-safe hash version).
    ///
    /// @param hash The original hash.
    /// @param signature The signature of the replay-safe hash to validate.
    ///
    /// @return result `0x1626ba7e` if validation succeeded, else `0xffffffff`.
    function isValidSignature(bytes32 hash, bytes calldata signature) public view virtual returns (bytes4 result) {
        if (_isValidSignature({hash: _eip712Hash({account: address(this), hash: hash}), signature: signature})) {
            // bytes4(keccak256("isValidSignature(bytes32,bytes)"))
            return 0x1626ba7e;
        }

        return 0xffffffff;
    }

    // TODO: Does it make sense to accept the `account` as parameter? Doing so makes it easier for ERC-6492 signature
    //       verification, otherwise we would most likely need to use a utility contract to generate EIP-712 hashes.
    //       See https://github.com/coinbase/smart-wallet/blob/main/src/utils/ERC1271InputGenerator.sol

    /// @notice Wrapper around `_eip712Hash()` to produce a replay-safe hash for the given `account`.
    ///
    /// @dev The returned EIP-712 compliant replay-safe hash is the result of:
    ///      keccak256(
    ///         \x19\x01 ||
    ///         this.domainSeparator ||
    ///         hashStruct(ReplaySafeHashWrapper({ hash: `hash`}))
    ///      )
    ///
    /// @param account The account address.
    /// @param hash The original hash.
    ///
    /// @return The corresponding replay-safe hash.
    function replaySafeHash(address account, bytes32 hash) public view virtual returns (bytes32) {
        return _eip712Hash({account: account, hash: hash});
    }

    /// @notice Returns the `domainSeparator` used to create EIP-712 compliant hashes.
    ///
    /// @dev Implements domainSeparator = hashStruct(eip712Domain).
    ///      See https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator.
    ///
    /// @return The 32 bytes domain separator result.
    function domainSeparator() public view returns (bytes32) {
        return _domainSeparator(address(this));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                       INTERNAL FUNCTIONS                                       //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Returns the domain name and version to use when creating EIP-712 signatures.
    ///
    /// @dev MUST be defined by the implementation.
    ///
    /// @return name The user readable name of signing domain.
    /// @return version The current major version of the signing domain.
    function _domainNameAndVersion() internal view virtual returns (string memory name, string memory version);

    /// @notice Validates the `signature` against the given `hash`.
    ///
    /// @dev MUST be defined by the implementation.
    ///
    /// @param hash The hash whose signature has been performed on.
    /// @param signature The signature associated with `hash`.
    ///
    /// @return `true` is the signature is valid, else `false`.
    function _isValidSignature(bytes32 hash, bytes memory signature) internal view virtual returns (bool);

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                        PRIVATE FUNCTIONS                                       //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Returns the `domainSeparator` for the given `account` used to create EIP-712 compliant hashes.
    ///
    /// @dev Implements domainSeparator = hashStruct(eip712Domain).
    ///      See https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator.
    ///
    /// @param account The account address.
    ///
    /// @return The 32 bytes domain separator result.
    function _domainSeparator(address account) public view returns (bytes32) {
        (string memory name, string memory version) = _domainNameAndVersion();
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                account
            )
        );
    }

    /// @notice Returns the EIP-712 typed hash of the `ReplaySafeHashWrapper(bytes32 hash)` data structure.
    ///
    /// @dev Implements encode(domainSeparator : 𝔹²⁵⁶, message : 𝕊) = "\x19\x01" || domainSeparator ||
    ///      hashStruct(message).
    /// @dev See https://eips.ethereum.org/EIPS/eip-712#specification.
    ///
    /// @param hash The `ReplaySafeHashWrapper.hash` field to hash.
    ////
    /// @return The resulting EIP-712 hash.
    function _eip712Hash(address account, bytes32 hash) private view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(account), _hashStruct(hash)));
    }

    /// @notice Returns the EIP-712 `hashStruct` result of the `ReplaySafeHashWrapper(bytes32 hash)` data
    ///         structure.
    ///
    /// @dev Implements hashStruct(s : 𝕊) = keccak256(typeHash || encodeData(s)).
    /// @dev See https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
    ///
    /// @param hash The `ReplaySafeHashWrapper.hash` field.
    ///
    /// @return The EIP-712 `hashStruct` result.
    function _hashStruct(bytes32 hash) private pure returns (bytes32) {
        return keccak256(abi.encode(_MESSAGE_TYPEHASH, hash));
    }
}
