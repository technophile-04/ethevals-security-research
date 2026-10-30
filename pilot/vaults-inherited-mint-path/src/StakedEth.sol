// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract WETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}
    function deposit() external payable { _mint(msg.sender, msg.value); }
}

interface IWETH { function deposit() external payable; }

// The three functions in the instruction, verbatim.
contract StakedEth is ERC4626 {
    using SafeERC20 for IERC20;
    uint256 constant MIN_DEPOSIT = 0.01 ether;

    constructor(IERC20 weth) ERC20("Staked ETH", "sETH") ERC4626(weth) {}

    function depositETH(address receiver) external payable returns (uint256 shares) {
        shares = previewDeposit(msg.value);
        IWETH(asset()).deposit{value: msg.value}();
        _deposit(msg.sender, receiver, msg.value, shares);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        shares = previewDeposit(assets);
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
        _deposit(msg.sender, receiver, assets, shares);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        require(assets >= MIN_DEPOSIT, "too small");
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }
}
