pragma solidity 0.8.28;
contract Pool {
    mapping(bytes32 => uint) public positions;
    function add(address manager, int24 lo, int24 hi) external payable {
        positions[keccak256(abi.encodePacked(manager, lo, hi))] += msg.value;
    }
}
contract Vault {
    Pool public immutable pool;
    address public immutable manager;
    uint public supply = 100;
    mapping(address => uint) public shares;
    constructor(Pool p, address m) { pool = p; manager = m; shares[msg.sender]=100; }
    function assets() public view returns (uint) {
        bytes32 key = keccak256(abi.encodePacked(manager, int24(-40), int24(40)));
        return pool.positions(key);
    }
    function deposit() external payable {
        uint minted = msg.value * supply / assets();
        shares[msg.sender] += minted; supply += minted;
        pool.add{value: msg.value}(manager, -40, 40);
    }
}
