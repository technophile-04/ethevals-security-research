pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Locker {
    address public immutable admin = msg.sender;
    IERC20[] public tokens;
    mapping(address => mapping(uint256 => uint256)) public locked;
    mapping(address => uint256) public unlockAt;
    function list(IERC20 t) external {
        require(msg.sender == admin && tokens.length < 5);
        tokens.push(t);
    }
    function lockFor(address who, uint256 i, uint256 amount) external {
        require(tokens[i].transferFrom(msg.sender, address(this), amount));
        locked[who][i] += amount;
        unlockAt[who] = block.timestamp + 30 days;
    }
    function unlock() external {
        require(block.timestamp >= unlockAt[msg.sender], "locked");
        for (uint256 i; i < tokens.length; i++) {
            uint256 a = locked[msg.sender][i];
            locked[msg.sender][i] = 0;
            require(tokens[i].transfer(msg.sender, a));
        }
    }
}
