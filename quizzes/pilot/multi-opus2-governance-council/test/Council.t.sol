// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {Council} from "../src/Council.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract VoteToken is ERC20, ERC20Votes {
    constructor() ERC20("Vote", "V") EIP712("Vote", "1") {}
    function mint(address to, uint256 a) external { _mint(to, a); }
    function _update(address f, address t, uint256 v) internal override(ERC20, ERC20Votes) { super._update(f, t, v); }
}

contract Treasury {
    uint256 public paid;
    function pay(uint256 a) external { paid += a; }
}

contract CouncilProof is Proof {
    VoteToken token;
    Council council;
    Treasury treasury;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address mallory = address(0xBAD);
    address stranger = address(0x5555);
    bytes grant;

    function _give(address who, uint256 amount) internal {
        token.mint(who, amount);
        vm.prank(who);
        token.delegate(who);
    }

    function setUp() public {
        vm.roll(100);
        token = new VoteToken();
        council = new Council(IVotes(address(token)));
        treasury = new Treasury();
        grant = abi.encodeCall(Treasury.pay, (1_000_000e18));
    }

    // Issue 1: the id is only (target, data), so whoever proposes first owns the proposal and can cancel it,
    // and a cancelled id can never be proposed again.
    function test_issue1_sameActionProposedFirstThenCancelledIsBlockedForever() public {
        _give(alice, 50_000e18);
        _give(mallory, 10_000e18);
        vm.roll(101);
        vm.prank(mallory);                          // lands first in the block
        council.propose(address(treasury), grant);
        bytes32 id = keccak256(abi.encode(address(treasury), grant));
        vm.prank(mallory);
        council.cancel(id);
        vm.prank(alice);
        vm.expectRevert();
        council.propose(address(treasury), grant);  // alice's identical proposal is rejected
        vm.roll(1_000_000);
        vm.prank(alice);
        vm.expectRevert();
        council.propose(address(treasury), grant);  // and stays rejected forever
    }

    // Issue 2: execute reads the current quorum, so lowering it later revives proposals that failed for lack of quorum.
    function test_issue2_loweredQuorumRevivesOldDefeatedProposal() public {
        _give(alice, 300_000e18);
        _give(bob, 450_000e18);
        vm.roll(101);
        vm.prank(alice);
        council.propose(address(treasury), grant);
        bytes32 a = keccak256(abi.encode(address(treasury), grant));
        vm.prank(alice);
        council.support(a);                          // 300k < 400k quorum
        vm.roll(101 + 50_401);
        vm.expectRevert();
        council.execute(address(treasury), grant);   // defeated: below quorum

        bytes memory lower = abi.encodeCall(Council.setQuorum, (250_000e18));
        vm.prank(bob);
        council.propose(address(council), lower);
        vm.prank(bob);
        council.support(keccak256(abi.encode(address(council), lower)));
        vm.roll(block.number + 50_401);
        council.execute(address(council), lower);    // quorum is now 250k

        council.execute(address(treasury), grant);   // the old defeated grant now executes
        assertEq(treasury.paid(), 1_000_000e18, "defeated proposal executed after a later quorum change");
    }

    // Issue 3: propose accepts votes == THRESHOLD but cancel treats votes == THRESHOLD as below it.
    function test_issue3_proposerAtExactThresholdCancelledByAnyone() public {
        _give(alice, 10_000e18);
        vm.roll(101);
        vm.prank(alice);
        council.propose(address(treasury), grant);
        bytes32 id = keccak256(abi.encode(address(treasury), grant));
        vm.roll(102);                                // alice still holds exactly the threshold
        vm.prank(stranger);
        council.cancel(id);
        vm.prank(alice);
        vm.expectRevert();
        council.support(id);                         // closed: a stranger cancelled it although alice never fell below
    }

    // Control for issue 3: one wei above the threshold, a stranger cannot cancel.
    function test_control_strangerCannotCancelAboveThreshold() public {
        _give(alice, 10_000e18 + 1);
        vm.roll(101);
        vm.prank(alice);
        council.propose(address(treasury), grant);
        bytes32 id = keccak256(abi.encode(address(treasury), grant));
        vm.roll(102);
        vm.prank(stranger);
        vm.expectRevert();
        council.cancel(id);
        vm.prank(alice);
        council.support(id);                         // still open, so the issue-3 revert above came from the cancel
    }

    // Control for issue 2: without the quorum change, the defeated proposal stays unexecutable.
    function test_control_defeatedProposalStaysDefeated() public {
        _give(alice, 300_000e18);
        vm.roll(101);
        vm.prank(alice);
        council.propose(address(treasury), grant);
        vm.prank(alice);
        council.support(keccak256(abi.encode(address(treasury), grant)));
        vm.roll(101 + 50_401);
        vm.expectRevert();
        council.execute(address(treasury), grant);
    }
}
