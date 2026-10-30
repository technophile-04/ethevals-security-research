// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract Model {
    mapping(address => bool) public minter;
    mapping(address => bool) public blocked;
    mapping(address => bool) public listed;
    mapping(address => uint256) public balanceOf;
    constructor(bool isListed, bool isBlocked) {
        listed[msg.sender] = isListed; blocked[msg.sender] = isBlocked;
        listed[address(0xAAA)] = true; balanceOf[msg.sender] = 100;
    }
    function _burn(address from, uint256 n) internal { balanceOf[from] -= n; }
    function transfer(address to, uint256 n) external {
        require(permitted(msg.sender, to)); balanceOf[msg.sender] -= n; balanceOf[to] += n;
    }
function permitted(address from, address to) internal view returns (bool) {
    if (minter[msg.sender] && !blocked[from] && to == address(0))
        return true;
    if (listed[msg.sender] && listed[from] && to == address(0))
        return true;
    return listed[msg.sender] && listed[from] && listed[to]
        && !blocked[msg.sender] && !blocked[from] && !blocked[to];
}
function burn(uint256 amount) external {
    require(permitted(msg.sender, address(0)));
    _burn(msg.sender, amount);
}
}
contract Proof {
    function testListedBlockedHolderBurnsEntireRecoverableBalance() external {
        Model m = new Model(true, true); m.burn(100);
        require(m.balanceOf(address(this)) == 0, "recoverable balance survives");
    }
    function testUnlistedBlockedHolderCannotBurn() external {
        Model m = new Model(false, true);
        (bool ok,) = address(m).call(abi.encodeCall(m.burn, (100)));
        require(!ok && m.balanceOf(address(this)) == 100, "unlisted holder burns");
    }
    function testListedUnblockedHolderCanBurn() external {
        Model m = new Model(true, false); m.burn(100);
        require(m.balanceOf(address(this)) == 0, "intended burn fails");
    }
    function testBlockedHolderCannotTransferNormally() external {
        Model m = new Model(true, true);
        (bool ok,) = address(m).call(abi.encodeCall(m.transfer, (address(0xAAA), 100)));
        require(!ok && m.balanceOf(address(this)) == 100, "normal transfer ignores blocking");
    }
}
