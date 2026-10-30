// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

interface Vm { function prank(address) external; }

contract Vault is Ownable2Step {
    address transient activeCaller;
    constructor() Ownable(msg.sender) {}
    function run() external {
        activeCaller = msg.sender;
        delete activeCaller;
    }
}

contract Proof {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant BOB = address(0xB0B);
    function testRenounceIsFinal() public {
        Vault v = new Vault();
        v.transferOwnership(BOB);
        vm.prank(BOB); v.acceptOwnership();
        vm.prank(BOB); v.renounceOwnership();
        require(v.pendingOwner() == address(0), "pending owner not cleared");
        vm.prank(BOB);
        (bool ok,) = address(v).call(abi.encodeCall(v.acceptOwnership, ()));
        require(!ok && v.owner() == address(0), "bob reclaimed");
    }
}
