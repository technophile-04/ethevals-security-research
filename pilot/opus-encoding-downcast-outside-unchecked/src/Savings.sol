pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Savings {
    IERC20 public immutable token;
    mapping(address => uint64) public credit;
    constructor(IERC20 t) { token = t; }

    function deposit(uint64 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount));
        credit[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        uint64 c = credit[msg.sender];
        uint64 debit = uint64(amount);
        require(c >= debit, "insufficient");
        unchecked { credit[msg.sender] = c - debit; }
        require(token.transfer(msg.sender, amount));
    }
}
