// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./BuilderState.sol";

abstract contract BuilderModifiers is BuilderState {
    error NoZeroAmount();
    error InvalidParamsLength(uint256 paramsLength, uint256 minLength);

    modifier notZeroAddress(address _address) {
        _notZeroAddress(_address);
        _;
    }
    
    modifier validUserData(UserPool memory userData) {
        _notZeroAddress(userData.user);
        _notZeroAmount(userData.amount);
        _;
    }

    function _notZeroAmount(uint256 amount) internal pure {
        if (amount == 0) revert NoZeroAmount();
    }

    function _notZeroAddress(address _address) internal pure {
        if (_address == address(0)) revert NoZeroAddress();
    }

    function _validParamsLength(uint256 paramsLength, uint256 minLength) internal pure {
        if (paramsLength < minLength) revert InvalidParamsLength(paramsLength, minLength);
    }
}
