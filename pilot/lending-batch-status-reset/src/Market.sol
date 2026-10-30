// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PlainToken is ERC20 {
    constructor(string memory n) ERC20(n, n) {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

// The snippet in the instruction is `run` and `_customOp`, verbatim.
contract Market {
    uint8 constant DEPOSIT = 1;
    uint8 constant BORROW = 2;
    uint8 constant REPAY = 3;

    struct Flags { bool checkHealth; }

    PlainToken public immutable collateral;
    PlainToken public immutable debt;
    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;

    constructor(PlainToken c, PlainToken d) { collateral = c; debt = d; }

    function run(uint8[] calldata ops, bytes[] calldata args) external {
        Flags memory f;
        for (uint256 i; i < ops.length; i++) {
            if (ops[i] == DEPOSIT) _deposit(msg.sender, abi.decode(args[i], (uint256)));
            else if (ops[i] == BORROW) { _borrow(msg.sender, abi.decode(args[i], (uint256))); f.checkHealth = true; }
            else if (ops[i] == REPAY) _repay(msg.sender, abi.decode(args[i], (uint256)));
            else f = _customOp(ops[i], f, args[i]);
        }
        if (f.checkHealth) require(_healthy(msg.sender), "unhealthy");
    }

    function _customOp(uint8, Flags memory, bytes calldata) internal virtual returns (Flags memory) {}

    function _deposit(address u, uint256 a) internal { collateral.transferFrom(u, address(this), a); collateralOf[u] += a; }
    function _borrow(address u, uint256 a) internal { debtOf[u] += a; debt.transfer(u, a); }
    function _repay(address u, uint256 a) internal { debt.transferFrom(u, address(this), a); debtOf[u] -= a; }
    function _healthy(address u) internal view returns (bool) { return debtOf[u] * 100 <= collateralOf[u] * 80; }
}
