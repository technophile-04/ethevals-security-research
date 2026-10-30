// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
interface Vm { function prank(address) external; }
contract Vault is Ownable2Step {
    bool transient locked;
    constructor() Ownable(msg.sender) {}
    modifier nonReentrant() { require(!locked); locked = true; _; delete locked; }
    function run() external nonReentrant {}
}
contract Proof {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    function testBoolLock() public {
        Vault v = new Vault(); address bob = address(0xB0B);
        v.transferOwnership(bob); vm.prank(bob); v.acceptOwnership(); vm.prank(bob); v.renounceOwnership();
        v.run(); v.run();
        require(false, string.concat("pendingAfterRenounce=", v.pendingOwner() == bob ? "bob" : "zero"));
    }
}
