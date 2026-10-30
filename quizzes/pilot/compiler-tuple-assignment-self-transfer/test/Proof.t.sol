// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Token {
    mapping(address => uint256) public balanceOf;
    constructor(address holder) { balanceOf[holder] = 100; }
    function transfer(address to, uint256 amount) external {
        uint256 fromBal = balanceOf[msg.sender];
        uint256 toBal = balanceOf[to];
        require(fromBal >= amount, "balance");
        (balanceOf[msg.sender], balanceOf[to]) = (fromBal - amount, toBal + amount);
    }
}

contract Proof {
    function testSelfTransferEndsAt60() public {
        Token t = new Token(address(this));
        t.transfer(address(this), 40);
        require(t.balanceOf(address(this)) == 60, "not 60");
    }
    // Control: an ordinary transfer is correct.
    function testNormalTransfer() public {
        Token t = new Token(address(this));
        t.transfer(address(0xB0B), 40);
        require(t.balanceOf(address(this)) == 60 && t.balanceOf(address(0xB0B)) == 40, "normal transfer");
    }
}
