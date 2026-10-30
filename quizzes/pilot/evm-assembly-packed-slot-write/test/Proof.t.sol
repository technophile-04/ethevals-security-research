// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract Vault {
    address public owner;
    bool public paused;

    constructor() { owner = msg.sender; }

    function pause() external {
        require(msg.sender == owner, "not owner");
        assembly { sstore(paused.slot, 1) }
    }

    function slotAndOffset() external pure returns (uint256 s, uint256 o) {
        assembly { s := paused.slot o := paused.offset }
    }
}

contract Proof {
    function testPauseOverwritesOwner() public {
        Vault v = new Vault();
        require(v.owner() == address(this), "owner");
        v.pause();
        require(v.owner() == address(1), "owner not 0x...01");
        require(!v.paused(), "paused set");
        (uint256 s, uint256 o) = v.slotAndOffset();
        require(s == 0 && o == 20, "layout");
        (bool ok,) = address(v).call(abi.encodeCall(v.pause, ()));
        require(!ok, "old owner still owner");
    }
}
