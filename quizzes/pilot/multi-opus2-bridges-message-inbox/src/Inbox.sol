// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
interface IProver { function proven(bytes32 h) external view returns (bool); }

contract Inbox {
    struct Message { uint256 nonce; address to; uint256 value; uint256 fee; uint256 gasLimit; bytes data; }
    IProver immutable prover;
    address immutable guardian;
    mapping(bytes32 => uint64) receivedAt;
    mapping(bytes32 => uint8) status;

    constructor(IProver p, address g) { prover = p; guardian = g; }

    function prove(bytes32 h) external {
        require(receivedAt[h] == 0 && prover.proven(h));
        receivedAt[h] = uint64(block.timestamp);
    }

    function hold(bytes32 h, bool on) external {
        require(msg.sender == guardian);
        receivedAt[h] = on ? type(uint64).max : uint64(block.timestamp);
    }

    function process(Message calldata m) external {
        bytes32 h = keccak256(abi.encode(m));
        uint64 t = receivedAt[h];
        require(status[h] == 0 && t != 0 && t != type(uint64).max && block.timestamp >= t + 1 hours);
        status[h] = 1;
        (bool ok,) = m.to.call{value: m.value, gas: m.gasLimit}(m.data);
        if (!ok) status[h] = 2;
        payable(msg.sender).transfer(m.fee);
    }

    function retry(Message calldata m) external {
        bytes32 h = keccak256(abi.encode(m));
        require(msg.sender == m.to && status[h] == 2);
        status[h] = 1;
        (bool ok,) = m.to.call{value: m.value}(m.data);
        require(ok);
    }
}
