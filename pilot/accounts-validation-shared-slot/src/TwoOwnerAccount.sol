// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAccount} from "account-abstraction/interfaces/IAccount.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// validateUserOp and execute are the instruction's snippet, verbatim.
contract TwoOwnerAccount is IAccount {
    address public immutable entryPoint;
    mapping(address => uint256) public limit;
    address private activeOwner;

    modifier onlyEntryPoint() { require(msg.sender == entryPoint, "entry point"); _; }

    constructor(address ep, address a, uint256 limitA, address b, uint256 limitB) {
        entryPoint = ep; limit[a] = limitA; limit[b] = limitB;
    }

    function validateUserOp(PackedUserOperation calldata op, bytes32 userOpHash, uint256 missing)
        external onlyEntryPoint returns (uint256)
    {
        address signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(userOpHash), op.signature);
        if (limit[signer] == 0) return 1;
        activeOwner = signer;
        if (missing > 0) { (bool paid,) = payable(msg.sender).call{value: missing}(""); paid; }
        return 0;
    }

    function execute(address to, uint256 value) external onlyEntryPoint {
        require(value <= limit[activeOwner], "over limit");
        (bool ok,) = to.call{value: value}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}
