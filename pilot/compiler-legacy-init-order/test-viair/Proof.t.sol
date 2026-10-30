// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FeeVault is Ownable {
    address public feeRecipient = owner();
    constructor() Ownable(msg.sender) {}

    function collectFees() external {
        payable(feeRecipient).transfer(address(this).balance);
    }
}

contract Deployer { function deploy() external returns (FeeVault v) { v = new FeeVault(); } }

contract Proof {
    // legacy pipeline: all state-variable initializers in the hierarchy run before any constructor
    function testViaIRFeeRecipientIsDeployer() public {
        Deployer alice = new Deployer();
        FeeVault v = alice.deploy();
        require(v.owner() == address(alice), "owner not deployer");
        require(v.feeRecipient() == address(alice), "feeRecipient not deployer");
    }
}
