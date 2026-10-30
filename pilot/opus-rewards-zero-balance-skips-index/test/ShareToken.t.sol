// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Vm.sol";
import {ShareToken} from "../src/ShareToken.sol";

// A holder contract whose receive() re-enters claim (it keeps no counter: the 2300-gas
// stipend cannot pay for a storage write). `swallow` picks whether it lets the
// inner failure bubble up (revert) or catches it and returns normally.
contract Reenterer {
    ShareToken public share;
    bool public swallow;
    constructor(ShareToken s, bool sw) { share = s; swallow = sw; }
    function claim() external { share.claim(); }
    receive() external payable {
        if (swallow) {
            (bool ok,) = address(share).call(abi.encodeCall(ShareToken.claim, ()));
            ok;
        } else {
            share.claim();
        }
    }
}

contract Plain {
    ShareToken public share;
    constructor(ShareToken s) { share = s; }
    function claim() external { share.claim(); }
    receive() external payable {}
}

contract ShareTokenProof is Proof {
    ShareToken share;
    address bob = address(0xB0B);   // fresh address that buys shares after the payout

    function setUp() public {
        share = new ShareToken();   // this contract holds all 1000 shares
    }

    // Decoy, part 1: claim pays before zeroing owed, but transfer forwards only the 2300-gas
    // stipend, so a re-entering receive() cannot complete a second claim: the whole claim reverts.
    function test_decoy_reentryThroughTransferReverts() public {
        Reenterer r = new Reenterer(share, false);
        share.transfer(address(r), 500e18);
        share.notify{value: 10 ether}();
        uint256 owedBefore = 5 ether;
        vm.expectRevert();
        r.claim();
        assertEq(address(r).balance, 0, "no ETH left the contract");
        assertEq(address(share).balance, 10 ether, "pot intact");
        // Its 5 ETH is still owed (settled lazily on the next claim), nothing was paid twice.
        assertEq(share.balanceOf(address(r)) * (share.index() - share.paidIndex(address(r))) / 1e18 + share.owed(address(r)), owedBefore, "still owed once");
    }

    // Decoy, part 2: even a receiver that catches the failed inner claim runs out of the stipend,
    // so every re-entry attempt reverts the outer claim. A plain contract holder is paid exactly once.
    function test_decoy_swallowedReentryAlsoReverts() public {
        Reenterer r = new Reenterer(share, true);
        share.transfer(address(r), 500e18);
        share.notify{value: 10 ether}();
        vm.expectRevert();
        r.claim();
        assertEq(address(share).balance, 10 ether, "pot intact");
    }

    function test_decoy_plainContractHolderPaidOnce() public {
        Plain p = new Plain(share);
        share.transfer(address(p), 500e18);
        share.notify{value: 10 ether}();
        p.claim();
        p.claim();
        assertEq(address(p).balance, 5 ether, "paid its share exactly once");
        assertEq(share.owed(address(p)), 0, "owed cleared");
        assertEq(address(share).balance, 5 ether, "the rest stays for the other holder");
    }

    // Real cause: _settle returns early for a zero balance without stamping paidIndex, so a
    // fresh holder keeps paidIndex 0 and its first settle charges the whole history to its new balance.
    function test_loss_freshHolderCollectsHistory() public {
        share.notify{value: 10 ether}();      // 0.01 ETH per share, all owed to this contract
        share.transfer(bob, 100e18);         // bob buys 100 shares after the payout
        assertEq(share.paidIndex(bob), 0, "bob was never stamped");

        vm.prank(bob);
        share.claim();
        assertEq(bob.balance, 1 ether, "bob collects 1 ETH from a payout he did not hold for");

        // The long-time holder is owed the full 10 ETH but only 9 ETH remain.
        assertEq(share.owed(address(this)), 10 ether, "holder owed 10 ETH");
        vm.expectRevert();
        share.claim();
    }

    receive() external payable {}
}
