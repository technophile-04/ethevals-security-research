// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IStaker {
    function stake() external payable;
    function unstake(uint256 amount) external;
    function staked() external view returns (uint256);
}

contract StakePool is ERC20("Pool ETH", "pETH"), ReentrancyGuard {
    IStaker immutable staker;
    address immutable keeper;
    mapping(address => uint256) public owed;

    constructor(IStaker s, address k) { staker = s; keeper = k; }

    receive() external payable nonReentrant {}

    function totalAssets() public view returns (uint256) {
        return address(this).balance + staker.staked();
    }

    function deposit() external payable nonReentrant {
        uint256 supply = totalSupply();
        _mint(msg.sender, supply == 0 ? msg.value : msg.value * supply / (totalAssets() - msg.value));
    }

    function requestWithdraw(uint256 shares) external nonReentrant {
        owed[msg.sender] += shares * totalAssets() / totalSupply();
        _burn(msg.sender, shares);
    }

    function claim() external nonReentrant {
        uint256 amount = owed[msg.sender];
        owed[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok);
    }

    function rebalance(uint256 toStake, uint256 fromStake) external nonReentrant {
        require(msg.sender == keeper);
        if (toStake > 0) staker.stake{value: toStake}();
        if (fromStake > 0) staker.unstake(fromStake);
    }
}
