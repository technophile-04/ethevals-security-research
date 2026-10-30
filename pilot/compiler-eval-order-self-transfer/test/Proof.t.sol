// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract Token {
    mapping(address => uint256) public balanceOf;
    constructor(address holder) { balanceOf[holder] = 100; }
    function transfer(address to, uint256 amount) external {
        balanceOf[to] = balanceOf[to] + _debit(msg.sender, amount);
    }
    function _debit(address from, uint256 amount) internal returns (uint256) {
        balanceOf[from] -= amount;
        return amount;
    }
}

contract Proof {
    function testSelfTransferLegacy() public {
        Token t = new Token(address(this));
        t.transfer(address(this), 40);
        require(t.balanceOf(address(this)) == 100, "legacy: balance not 100");
    }
}
