// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

abstract contract Pausable {
    bool public paused;

    event Paused(address indexed sender);
    event Unpaused(address indexed sender);

    error IsPaused();
    error NotPaused();

    function _pause() internal whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    modifier whenNotPaused() {
        if (paused) revert IsPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }
}
