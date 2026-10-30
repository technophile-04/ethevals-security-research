pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreditPool is ERC20("Credit USDC", "cUSDC") {
    IERC20 public immutable usdc;
    address public immutable borrower;
    uint256 public owed;
    uint256 public last = block.timestamp;

    constructor(IERC20 u, address b) { usdc = u; borrower = b; }

    function accrue() public {
        owed += owed * (block.timestamp - last) / 10 / 365 days;
        last = block.timestamp;
    }

    function totalAssets() public view returns (uint256) {
        return usdc.balanceOf(address(this)) + owed;
    }

    function deposit(uint256 amount) external {
        accrue();
        uint256 s = totalSupply();
        _mint(msg.sender, s == 0 ? amount : amount * s / totalAssets());
        usdc.transferFrom(msg.sender, address(this), amount);
        require(totalSupply() <= 5_000_000e6, "cap");
    }

    function redeem(uint256 shares) external {
        accrue();
        uint256 amount = shares * totalAssets() / totalSupply();
        _burn(msg.sender, shares);
        usdc.transfer(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(msg.sender == borrower);
        accrue();
        require(usdc.balanceOf(address(this)) * 5 >= totalAssets(), "reserve");
        owed += amount;
        usdc.transfer(borrower, amount);
    }

    function repay(uint256 amount) external {
        accrue();
        usdc.transferFrom(msg.sender, address(this), amount);
        owed -= amount;
    }
}
