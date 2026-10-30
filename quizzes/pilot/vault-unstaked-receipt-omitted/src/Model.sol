pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract Booster {
    mapping(address => uint) public staked; mapping(address => uint) public receipts;
    function credit(address who, uint n, bool stake) external {
        require(msg.sender==who);
        if (stake) staked[who] += n;
        else receipts[who] += n;
    }
}
contract Vault {
    IERC20 public cash; Booster public booster;
    uint public supply = 100; mapping(address => uint) public shares;
    function invest(uint n, bool stake) external {
        SafeERC20.safeTransfer(cash,address(booster),n);
        booster.credit(address(this), n, stake);
    }
    function assets() public view returns (uint) { return cash.balanceOf(address(this)) + booster.staked(address(this)); }
    function deposit(uint n) external {
        uint s = n * supply / assets();
        SafeERC20.safeTransferFrom(cash,msg.sender,address(this),n);
        shares[msg.sender] += s; supply += s;
    }
}
