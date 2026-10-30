pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ShareToken is ERC20("Share", "SHR") {
    uint256 public index;
    mapping(address => uint256) public paidIndex;
    mapping(address => uint256) public owed;
    constructor() { _mint(msg.sender, 1000e18); }
    function notify() external payable { index += msg.value * 1e18 / totalSupply(); }
    function _settle(address a) internal {
        uint256 bal = balanceOf(a);
        if (bal == 0) return;
        owed[a] += bal * (index - paidIndex[a]) / 1e18;
        paidIndex[a] = index;
    }
    function _update(address from, address to, uint256 v) internal override {
        _settle(from); _settle(to);
        super._update(from, to, v);
    }
    function claim() external {
        _settle(msg.sender);
        payable(msg.sender).transfer(owed[msg.sender]);
        owed[msg.sender] = 0;
    }
}
