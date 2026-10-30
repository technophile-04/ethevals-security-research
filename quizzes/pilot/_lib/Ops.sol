// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

library Ops {
    function build(address sender, uint256 nonce, bytes memory callData, uint128 verificationGas, uint128 callGas,
        uint256 preVerificationGas, uint128 maxPriorityFee, uint128 maxFee) internal pure returns (PackedUserOperation memory op) {
        op.sender = sender;
        op.nonce = nonce;
        op.initCode = "";
        op.callData = callData;
        op.accountGasLimits = bytes32((uint256(verificationGas) << 128) | callGas);
        op.preVerificationGas = preVerificationGas;
        op.gasFees = bytes32((uint256(maxPriorityFee) << 128) | maxFee);
        op.paymasterAndData = "";
        op.signature = "";
    }
}
