// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Pausable} from "src/lib/Pausable.sol";

contract MockPausable is Pausable {
    function pause() external {
        _pause();
    }

    function unpause() external {
        _unpause();
    }
}

contract PausableTest is Test {
    MockPausable pausable;

    function setUp() public {
        pausable = new MockPausable();
    }

    event Paused(address indexed sender);
    event Unpaused(address indexed sender);

    function test_whenNotPaused() public {
        assertFalse(pausable.paused());
        vm.expectRevert(Pausable.NotPaused.selector);
        pausable.unpause();

        vm.expectEmit();
        emit Paused(address(this));
        pausable.pause();

        assertTrue(pausable.paused());
    }

    function test_whenPaused() public {
        pausable.pause();

        vm.expectRevert(Pausable.IsPaused.selector);
        pausable.pause();

        vm.expectEmit();
        emit Unpaused(address(this));
        pausable.unpause();

        assertFalse(pausable.paused());
    }
}
