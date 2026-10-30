pragma solidity 0.8.28;
interface Vm {
    function deal(address,uint) external;
    function warp(uint) external;
    function etch(address,bytes calldata) external;
    function store(address,bytes32,bytes32) external;
}
contract Base {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
}
