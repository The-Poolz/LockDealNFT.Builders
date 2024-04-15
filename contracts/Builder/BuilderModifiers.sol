// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./BuilderState.sol";

/// @title BuilderModifiers
/// @notice This contract contains modifiers and error handling for Builders
abstract contract BuilderModifiers is BuilderState {
    /// @dev Error thrown when an amount is zero
    error NoZeroAmount();
    /// @dev Error thrown when an address is zero
    error NoZeroAddress();
    /// @dev Error thrown when the length of parameters is invalid
    error InvalidParamsLength(uint256 paramsLength, uint256 minLength);

    /// @dev Modifier to ensure an address is not zero
    modifier notZeroAddress(address _address) {
        _notZeroAddress(_address);
        _;
    }
    
    /// @dev Modifier to ensure user data is valid
    modifier validUserData(UserPool memory userData) {
        _notZeroAddress(userData.user);
        _notZeroAmount(userData.amount);
        _;
    }

    /// @dev Internal function to check that an amount is not zero
    function _notZeroAmount(uint256 amount) internal pure {
        if (amount == 0) revert NoZeroAmount();
    }

    /// @dev Internal function to check that an address is not zero
    function _notZeroAddress(address _address) internal pure {
        if (_address == address(0)) revert NoZeroAddress();
    }

    /// @dev Internal function to check the validity of parameter length
    function _validParamsLength(uint256 paramsLength, uint256 minLength) internal pure {
        if (paramsLength < minLength) revert InvalidParamsLength(paramsLength, minLength);
    }
}