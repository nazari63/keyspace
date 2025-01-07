// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

abstract contract TransientUUPSUpgradeable is UUPSUpgradeable {
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                              TRANSIENT                                         //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Transient storage variable used to allow an upgrade.
    bool transient canUpgrade;

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                              ERRORS                                            //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the upgrade is not allowed.
    error UpgradeNotAllowed();

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                       INTERNAL FUNCTIONS                                       //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Explicitly allow the next upgrade by setting transient storage.
    function _allowUpgrade() internal {
        canUpgrade = true;
    }

    /// @inheritdoc UUPSUpgradeable
    ///
    /// @dev The uprade is authorized by reading transient storage.
    /// @dev Transient storage is reset.
    function _authorizeUpgrade(address) internal virtual override {
        require(canUpgrade, UpgradeNotAllowed());
        canUpgrade = false;
    }
}
