// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ERC20} from "oz/token/ERC20/ERC20.sol";
interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function warp(uint256) external;
    function addr(uint256) external returns (address);
    function sign(uint256,bytes32) external returns (uint8,bytes32,bytes32);
}
contract Token is ERC20 {
    constructor() ERC20("Asset","AST") {}
    function mint(address to,uint256 a) external { _mint(to,a); }
}
abstract contract Base {
    Vm internal constant vm=Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant ALICE=address(0xA11CE);
    address internal constant BOB=address(0xB0B);
    address internal constant CAROL=address(0xCA401);
}
