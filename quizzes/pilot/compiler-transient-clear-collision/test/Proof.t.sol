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
        // ... work that reads activeCaller ...
        delete activeCaller;
    }
}

contract Proof {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant BOB = address(0xB0B);

    function _renouncedByBob() internal returns (Vault v) {
        v = new Vault();
        v.transferOwnership(BOB);
        vm.prank(BOB); v.acceptOwnership();
        vm.prank(BOB); v.renounceOwnership();
        require(v.owner() == address(0), "renounce failed");
    }

    function testBobReclaimsAfterRenounce() public {
        Vault v = _renouncedByBob();
        require(v.pendingOwner() == BOB, "pending owner was cleared");
        vm.prank(BOB); v.acceptOwnership();
        require(v.owner() == BOB, "bob did not reclaim");
    }
}
