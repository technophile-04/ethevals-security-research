// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract Council {
    struct Proposal { address proposer; uint256 snapshot; uint256 end; uint256 votes; bool closed; }
    uint256 constant THRESHOLD = 10_000e18;
    uint256 quorum = 400_000e18;
    IVotes immutable token;
    mapping(bytes32 => Proposal) proposals;
    mapping(bytes32 => mapping(address => bool)) voted;

    constructor(IVotes t) { token = t; }

    function propose(address target, bytes calldata data) external {
        require(token.getPastVotes(msg.sender, block.number - 1) >= THRESHOLD);
        bytes32 id = keccak256(abi.encode(target, data));
        require(proposals[id].end == 0);
        proposals[id] = Proposal(msg.sender, block.number - 1, block.number + 50_400, 0, false);
    }

    function support(bytes32 id) external {
        Proposal storage p = proposals[id];
        require(block.number <= p.end && !p.closed && !voted[id][msg.sender]);
        voted[id][msg.sender] = true;
        p.votes += token.getPastVotes(msg.sender, p.snapshot);
    }

    function cancel(bytes32 id) external {
        Proposal storage p = proposals[id];
        require(msg.sender == p.proposer || token.getPastVotes(p.proposer, block.number - 1) <= THRESHOLD);
        p.closed = true;
    }

    function execute(address target, bytes calldata data) external {
        Proposal storage p = proposals[keccak256(abi.encode(target, data))];
        require(block.number > p.end && !p.closed && p.votes >= quorum);
        p.closed = true;
        (bool ok,) = target.call(data);
        require(ok);
    }

    function setQuorum(uint256 q) external {
        require(msg.sender == address(this));
        quorum = q;
    }
}
