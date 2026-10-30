// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function deal(address, uint256) external;
    function warp(uint256) external;
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function assume(bool) external;
}

contract Proof {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    function assertEq(uint256 a, uint256 b, string memory m) internal pure { require(a == b, m); }
    function assertEq(address a, address b, string memory m) internal pure { require(a == b, m); }
    function assertTrue(bool c, string memory m) internal pure { require(c, m); }
}
