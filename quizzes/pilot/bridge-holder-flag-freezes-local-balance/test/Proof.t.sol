// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract Model {
    mapping(address => uint256) public balanceOf;
    bool public locked = true;
    address public staking = address(0x777);
    address public bridge;
    error Restricted();
    modifier onlyBridge() { require(msg.sender == bridge); _; }
    constructor() { bridge = msg.sender; balanceOf[msg.sender] = 1000; }
    function _mint(address to, uint256 n) internal { balanceOf[to] += n; }
    function _transfer(address from, address to, uint256 n) internal {
        balanceOf[from] -= n; balanceOf[to] += n;
    }
mapping(address => bool) public imported;
function credit(address recipient, uint256 amount) external onlyBridge {
    _mint(recipient, amount);
    imported[recipient] = true;
}
function transfer(address to, uint256 amount) external returns (bool) {
    if (locked && imported[msg.sender] && to != staking)
        revert Restricted();
    _transfer(msg.sender, to, amount);
    return true;
}
}
contract Proof {
    function testUnsolicitedCreditRestrictsLocalBalance() external {
        Model m = new Model(); m.credit(address(this), 1);
        (bool ok,) = address(m).call(abi.encodeCall(m.transfer, (address(0xAAA), 1000)));
        require(!ok && m.balanceOf(address(this)) == 1001, "local balance still transferable");
    }
    function testLocalBalanceTransfersBeforeCredit() external {
        Model m = new Model(); require(m.transfer(address(0xAAA), 1000));
        require(m.balanceOf(address(0xAAA)) == 1000, "local transfer absent");
    }
    function testSendingImportedAmountToStakingDoesNotClearFlag() external {
        Model m = new Model(); m.credit(address(this), 1); m.transfer(m.staking(), 1);
        require(m.balanceOf(address(this)) == 1000 && m.imported(address(this)));
        (bool ok,) = address(m).call(abi.encodeCall(m.transfer, (address(0xAAA), 1000)));
        require(!ok, "flag cleared");
    }
}
