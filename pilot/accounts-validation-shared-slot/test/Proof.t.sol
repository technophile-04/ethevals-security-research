// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {vm} from "lib/Vm.sol";
import {Ops} from "lib/Ops.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TwoOwnerAccount} from "../src/TwoOwnerAccount.sol";

contract Proof {
    EntryPoint ep;
    TwoOwnerAccount acct;
    uint256 pkA = 0xA11CE;
    uint256 pkB = 0xB0B;
    address a;
    address b;
    address friendOfA = address(0xF1);
    address payable beneficiary = payable(address(0xBE));

    function setUp() public {
        ep = new EntryPoint();
        a = vm.addr(pkA);
        b = vm.addr(pkB);
        acct = new TwoOwnerAccount(address(ep), a, 10 ether, b, 0.1 ether);
        vm.deal(address(acct), 20 ether);
        vm.fee(0);
    }

    function _signed(uint256 pk, uint256 nonce, address to, uint256 value) internal returns (PackedUserOperation memory op) {
        op = Ops.build(address(acct), nonce, abi.encodeCall(TwoOwnerAccount.execute, (to, value)), 200_000, 100_000, 50_000, 1 gwei, 1 gwei);
        bytes32 h = MessageHashUtils.toEthSignedMessageHash(ep.getUserOpHash(op));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, h);
        op.signature = abi.encodePacked(r, s, v);
    }

    // Control: B's 5 ETH operation alone executes under B's own 0.1 ETH limit and fails.
    function testBAloneIsLimited() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _signed(pkB, uint256(1) << 64, b, 5 ether);
        vm.prank(b, b);
        ep.handleOps(ops, beneficiary);
        require(b.balance == 0, "B was paid");
    }

    // B bundles its own operation first and A's ordinary operation second. EntryPoint validates both
    // (activeOwner ends as A), then executes B's operation under A's 10 ETH limit.
    function testBundleOrderLendsALimitToB() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](2);
        ops[0] = _signed(pkB, uint256(1) << 64, b, 5 ether);  // nonce key 1
        ops[1] = _signed(pkA, 0, friendOfA, 1 ether);         // nonce key 0, A's own request
        vm.prank(b, b);
        ep.handleOps(ops, beneficiary);
        require(b.balance == 5 ether, "B not paid 5 ETH");
        require(friendOfA.balance == 1 ether, "A's op did not run");
    }
}
