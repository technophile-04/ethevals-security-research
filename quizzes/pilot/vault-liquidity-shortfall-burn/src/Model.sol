pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Reserve {
    IERC20 public immutable cash;
    address public immutable vault;
    constructor(IERC20 t) { cash = t; vault = msg.sender; }
    function release(uint n) external returns (uint got) {
        require(msg.sender == vault);
        uint liquid = cash.balanceOf(address(this));
        got = n < liquid ? n : liquid;
        require(cash.transfer(msg.sender, got));
    }
}
contract Vault {
    Reserve public immutable reserve;
    mapping(address => uint) public shares;
    constructor(IERC20 t) { reserve = new Reserve(t); shares[msg.sender] = 100; }
    function redeem(uint n) external {
        require(shares[msg.sender] >= n);
        uint got = reserve.release(n);
        shares[msg.sender] -= n;
        require(reserve.cash().transfer(msg.sender, got));
    }
}
