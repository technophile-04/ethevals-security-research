# EVM and Solidity security candidates

This file replaces any earlier draft.

Confidence estimates concern a frontier model's cold answer, not source accuracy. No model trials have run.

The final section records ideas that fail the incident requirement or the difficulty bar. EIP-7702 is outside this report.

### evm-transient-stipend-write
**Instruction:**
Can an ETH recipient change its own transient storage inside the 2,300-gas callback from `transfer` on Ethereum after Cancun? You are reviewing a vault whose safety argument says this gas allowance prevents every state write. Assume the recipient's entire callback fits within that allowance. Answer yes or no, then explain in one sentence.

**Answer:** Yes. EIP-1153 permits `TSTORE` below the stipend threshold that blocks `SSTORE`.

**Why a model gets it wrong:** It carries the persistent-storage gas restriction over to transient storage. The specific distinction is less familiar than generic warnings against `transfer`.

**Backing:** ChainSecurity's November 10, 2023 disclosure demonstrates low-gas reentrancy against transient state, including temporary allowances; no production loss claimed. https://www.chainsecurity.com/blog/tstore-low-gas-reentrancy/

**Spec source:** https://eips.ethereum.org/EIPS/eip-1153#specification

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** medium

### evm-compiler-assembly-write-removal
**Instruction:**
Does this helper reliably return 66 in a vault compiled with Solidity 0.8.14, the legacy pipeline, and the Yul optimizer enabled?
```solidity
function marker() external pure returns (uint256 x) {
    assembly { mstore(0, 66) }
    assembly { x := mload(0) }
}
```
You are checking whether the vault can trust its assembly scratch-memory helpers before launch. Answer yes or no, then explain in one sentence.

**Answer:** No. The affected optimizer removes the first block's memory write, so this helper returns zero.

**Why a model gets it wrong:** It executes the source mentally and overlooks a compiler bug tied to the pipeline and optimizer settings.

**Backing:** Solidity's June 15, 2022 security alert follows John Toman's report; versions 0.8.13 and 0.8.14 are affected. No production loss claimed. https://www.soliditylang.org/blog/2022/06/15/inline-assembly-memory-side-effects-bug/

**Spec source:** https://www.soliditylang.org/blog/2022/06/15/inline-assembly-memory-side-effects-bug/

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** high

### evm-compiler-tuple-cleanup
**Instruction:**
Can disabling the optimizer eliminate the known ABI re-encoding corruption risk in this bridge helper compiled with Solidity 0.8.15?
```solidity
function payload(bytes calldata message, uint256[2] calldata proof)
    external pure returns (bytes memory)
{
    return abi.encode(message, proof);
}
```
The bridge needs the encoded message bytes to survive unchanged. Answer yes or no, then explain in one sentence.

**Answer:** No. The calldata tuple re-encoding bug can overwrite the dynamic tail and affects both pipelines regardless of optimizer use.

**Why a model gets it wrong:** It treats compiler corruption as an optimizer-only risk or assumes checked arithmetic protects the encoder.

**Backing:** Solidity's August 8, 2022 security alert documents the bug, discovered by Chance Hudson; affected versions start at 0.5.8 and the fix is 0.8.16. No production loss claimed. https://www.soliditylang.org/blog/2022/08/08/calldata-tuple-reencoding-head-overflow-bug/

**Spec source:** https://www.soliditylang.org/blog/2022/08/08/calldata-tuple-reencoding-head-overflow-bug/

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** high

### evm-compiler-conditional-stop
**Instruction:**
Can this vault safely assume its first storage write survives `save(true)` when compiled with Solidity 0.8.16 and optimized via-IR?
```solidity
uint256 public saved;
function save(bool finish) external {
    saved = 1;
    finishEarly(finish);
    saved = 2;
}
function finishEarly(bool finish) internal {
    if (finish) { assembly { stop() } }
}
```
Assume `saved` starts at zero. Answer yes or no, then explain in one sentence.

**Answer:** No. The affected Yul optimizer can remove the first write despite the helper's successful early termination.

**Why a model gets it wrong:** It knows `STOP` commits state, then reasons from source semantics without checking the compiler version.

**Backing:** Solidity's September 8, 2022 security alert reports a medium/high-severity bug introduced in 0.8.13 and fixed in 0.8.17. No production loss claimed. https://www.soliditylang.org/blog/2022/09/08/storage-write-removal-before-conditional-termination/

**Spec source:** https://www.soliditylang.org/blog/2022/09/08/storage-write-removal-before-conditional-termination/

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** high

### evm-vyper-cross-function-lock
**Instruction:**
Does the shared `@nonreentrant("lock")` annotation prevent a callback from `withdraw` from entering `deposit` in a pool compiled with Vyper 0.2.16? Both functions use that annotation, but `withdraw` sends ETH before updating the balance that `deposit` reads. You are auditing the deployed bytecode's protection, not proposing a source rewrite. Answer yes or no, then explain in one sentence.

**Answer:** No. This compiler version assigns separate lock slots to the functions even when their lock names match.

**Why a model gets it wrong:** It assumes matching lock keys imply a shared lock. Likely known to frontier models familiar with the Curve incident.

**Backing:** Vyper's critical advisory GHSA-5824-cm3x-3c38, published August 5, 2023, documents cross-function reentrancy in 0.2.15, 0.2.16 and 0.3.0; 0.3.1 fixes it. https://github.com/vyperlang/vyper/security/advisories/GHSA-5824-cm3x-3c38

**Spec source:** https://github.com/vyperlang/vyper/security/advisories/GHSA-5824-cm3x-3c38

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

### evm-multicall-reuses-value
**Instruction:**
Can a depositor receive two ETH of accounting credit by sending one ETH once to this vault? Its payable `multicall` executes each item with `address(this).delegatecall`. Each item calls `deposit`, which adds `msg.value` to the caller's credit. The depositor supplies two `deposit` items, and no other checks or calls occur. Answer yes or no, then explain in one sentence.

**Answer:** Yes. Each delegatecall sees the original one-ETH `msg.value`, so the vault credits the same payment twice.

**Why a model gets it wrong:** It treats `msg.value` as a balance that a subcall consumes. Likely known to frontier models; keep only if calibration finds a miss.

**Backing:** Samczsun's 2021 MISO disclosure explains this exact delegatecall composition bug and connects it to Opyn's earlier repeated-payment exploit. https://samczsun.com/two-rights-might-make-a-wrong/

**Spec source:** The discoverer's delegatecall explanation and exploit construction: https://samczsun.com/two-rights-might-make-a-wrong/

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** low

### evm-p256-infinity-result
**Instruction:**
Must Ethereum's P256VERIFY precompile reject a signature whose recovered verification point is the point at infinity after Fusaka? You are auditing a passkey wallet. The input has the correct length, the signature scalars are in range, and the supplied public key is a valid non-infinity point on secp256r1. Answer yes or no, then explain in one sentence.

**Answer:** Yes. EIP-7951 separately checks the recovered point and returns empty data if that point is infinity.

**Why a model gets it wrong:** It treats public-key validation as sufficient or imports RIP-7212's incomplete verification rules.

**Backing:** EIP-7951, created May 27, 2025, discloses RIP-7212's missing recovered-infinity check and the resulting risk of client disagreement. This is a protocol defect disclosure, not a claimed wallet theft. https://eips.ethereum.org/EIPS/eip-7951#security-fixes

**Spec source:** https://eips.ethereum.org/EIPS/eip-7951#signature-verification-algorithm

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** medium

### evm-compiler-dirty-byte-push
**Instruction:**
Can a caller make the appended byte nonzero in this bridge's payload buffer, compiled with Solidity 0.8.14's legacy pipeline?
```solidity
bytes public payload;
function load(bytes calldata incoming) external {
    payload = incoming;
    payload.push();
}
```
The caller supplies 63 bytes and controls the unused calldata padding after them. The bridge assumes `push()` appends a zero byte. Answer yes or no, then explain in one sentence.

**Answer:** Yes. This compiler can copy dirty padding into storage and expose its first byte through the argumentless `push()`.

**Why a model gets it wrong:** It applies the documented zero-initialization rule without checking this compiler's bytes-copy bug.

**Backing:** Solidity's June 15, 2022 security alert supplies this calldata-copy pattern; the team explicitly reported no known exploitation. The fix shipped in 0.8.15. https://www.soliditylang.org/blog/2022/06/15/dirty-bytes-array-to-storage-bug/ and https://www.soliditylang.org/blog/2022/06/15/solidity-0.8.15-release-announcement/

**Spec source:** https://www.soliditylang.org/blog/2022/06/15/dirty-bytes-array-to-storage-bug/

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** medium

### evm-return-data-gas-cap
**Instruction:**
Does limiting the gas forwarded to an untrusted recipient also cap the gas that this bridge spends copying the recipient's return data?
```solidity
(bool ok, bytes memory result) = recipient.call{gas: callLimit}(message);
emit Result(ok, result);
```
The recipient can return or revert with a large byte array, and the bridge needs enough gas to record the outcome. Answer yes or no, then explain in one sentence.

**Answer:** No. Copying return data consumes gas in the bridge's frame and can exhaust its remaining gas despite the call limit.

**Why a model gets it wrong:** It assumes a callee gas cap contains every cost caused by the callee. Likely known to frontier models familiar with return bombs.

**Backing:** Paladin's Wallchain MetaIntents audit, September 13, 2023, issue 13, found return-bomb griefing and records the fix. No exploited loss claimed. https://paladinsec.co/assets/audits/20230913_Paladin_WallchainMetaIntents_Final_Report.pdf

**Spec source:** Nomad's implementation and explanation of capped copying: https://github.com/nomad-xyz/ExcessivelySafeCall

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

### evm-insufficient-gas-reward-update
**Instruction:**
Can a staker deliberately exhaust the reward hook's gas while still completing an emergency withdrawal? The staking contract forwards all available call gas to an external hook inside `try/catch`, ignores failure, then returns the stake. The hook consumes far more gas than the remaining withdrawal work. No check proves that the hook received enough gas. Assume an appropriate transaction gas limit exists. Answer yes or no, then explain in one sentence.

**Answer:** Yes. EIP-150 reserves gas in the caller, so the hook can run out while the caller catches its failure and completes withdrawal.

**Why a model gets it wrong:** It reads "all available call gas" as exhausting both frames together. Likely known in isolation; the reward-accounting consequence is more useful than a numerical gas puzzle.

**Backing:** Paladin's June 13, 2022 Sculptor Staking audit, issue 10, discloses this high-severity stale-rewards risk. No exploited loss claimed. https://paladinsec.co/assets/audits/20220613_Paladin_SculptorStaking_Final_Report.pdf

**Spec source:** https://eips.ethereum.org/EIPS/eip-150#specification

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** low

### evm-empty-code-token-success
**Instruction:**
Can this bridge accept a token deposit without moving tokens if `token` is the zero address?
```solidity
(bool ok, bytes memory data) = token.call(
    abi.encodeWithSignature("transferFrom(address,address,uint256)",
        msg.sender, address(this), amount)
);
require(ok && (data.length == 0 || abi.decode(data, (bool))));
```
The zero address has no code, the call sends no ETH, and no separate address check exists. Answer yes or no, then explain in one sentence.

**Answer:** Yes. The low-level call succeeds with empty return data, which the bridge accepts without any token transfer.

**Why a model gets it wrong:** It assumes calling a missing token contract reverts, or imports a code-existence check from a library absent here. Likely known.

**Backing:** Qubit's January 28, 2022 report explains how zero-address token transfers let attackers obtain unbacked bridge credit. The report establishes the exploit but does not give a dollar loss, so none is asserted here. https://medium.com/@QubitFin/protocol-exploit-report-305c34540fa3

**Spec source:** https://docs.soliditylang.org/en/latest/control-structures.html#error-handling-assert-require-revert-and-exceptions

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** low

### evm-selfdestruct-old-implementation
**Instruction:**
Can an attacker erase an old proxy implementation's code by making it delegatecall a newly deployed helper that executes `SELFDESTRUCT` on Ethereum after Cancun? The implementation was deployed a month earlier. The attacker calls the implementation directly, and the helper is created during the attack transaction. You are checking whether this recreates the old implementation-deletion attack. Answer yes or no, then explain in one sentence.

**Answer:** No. Delegatecall executes in the old implementation's context, so EIP-6780 preserves its code despite the helper's recent creation.

**Why a model gets it wrong:** It applies the same-transaction exception to the helper containing the opcode instead of the account executing it.

**Backing:** OpenZeppelin's September 16, 2021 UUPS post-mortem describes implementation deletion through delegatecall and reports successful mitigation without known losses. This question asks how Cancun changes that attack. https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680

**Spec source:** https://eips.ethereum.org/EIPS/eip-6780#specification

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

## Rejected on the way

- **Pectra/Fusaka dates:** Ethereum's roadmap confirms May 7 and December 3, 2025; dates alone fail the practical-security bar. https://ethereum.org/roadmap/
- **EIP-7623 calldata pricing:** The floor uses 10 gas per token, with four tokens per nonzero byte; it is not a universal replacement of 16 by 40 in the ordinary execution branch. The transaction must reserve the floor in its gas limit. Rejected because no named application incident was verified. https://eips.ethereum.org/EIPS/eip-7623
- **EIP-7825 gas-limit cap:** A transaction declaring more than 16,777,216 gas is invalid even if execution would use less; the block gas limit does not override it. Large deployment transactions, long loops and atomic batches that need more must change structure. Rejected because the verified source is a compatibility warning, not a named incident. https://eips.ethereum.org/EIPS/eip-7825
- **EIP-7883 ModExp:** The minimum rises from 200 to 500, and the formula changes beyond a uniform multiplier. Fixed-gas callers need review. Rejected because no affected production verifier or disclosed application bug was verified. https://eips.ethereum.org/EIPS/eip-7883
- **EIP-2537 BLS:** G1ADD and G2ADD omit subgroup checks; MSM and pairing check them. A successful addition alone cannot validate an untrusted signing key's subgroup. Rejected because no incident involving this exact precompile assumption was verified. https://eips.ethereum.org/EIPS/eip-2537#abi-for-operations
- **EIP-7951 alternatives:** Invalid signatures return empty data; the precompile does not impose low-s canonicalization, and its 6,900-gas cost differs from RIP-7212's 3,450. Rejected as extra candidates because the verified disclosure concerns recovered-infinity and modular-comparison defects, not losses from those wrapper assumptions. https://eips.ethereum.org/EIPS/eip-7951
- **Pectra blob capacity:** EIP-7691 sets target/max blobs per block to 6/9. Rejected because a capacity-recall question adds little security depth. https://eips.ethereum.org/EIPS/eip-7691
- **PeerDAS transaction versus block limit:** EIP-7594 caps each blob transaction at six blobs while nodes sample columns instead of all downloading every blob. A larger block allowance does not lift that transaction cap. Rejected because no named rollup outage from violating it was verified. https://eips.ethereum.org/EIPS/eip-7594
- **BPO changes:** EIP-7892 schedules changes to blob target, maximum and fee-update fraction through configuration. Rollup batchers and fee estimators cannot treat the major-fork name as their only configuration boundary. Rejected because no matching incident was verified. https://eips.ethereum.org/EIPS/eip-7892
- **Blob reserve price:** EIP-7918 changes the excess-blob-gas update when execution-linked reserve pricing dominates; treating the blob fee market as entirely independent becomes stale. Rejected because no named L2 security incident was verified. https://eips.ethereum.org/EIPS/eip-7918
- **MCOPY:** EIP-5656 introduces the memory-copy opcode; no matching vulnerability or loss was verified, so no overlap-copy puzzle was drafted. https://eips.ethereum.org/EIPS/eip-5656
- **Shifts, exponentiation and unchecked blocks:** Shifts truncate without overflow checks; exponentiation remains checked by default. `unchecked` does not propagate into called functions or suppress division-by-zero checks. Rejected because no incident tied to these exact distinctions was verified, and bare arithmetic examples fall below the bar. https://docs.soliditylang.org/en/latest/types.html#shifts and https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic
- **Short returndata and try/catch:** A promising distinction is failure during caller-side decoding versus failure in the external call. The Sculptor audit warns about unexpected returndata, but this pass did not fully verify a specific incident and the exact decoder/catch case. Do not treat that warning as proof of a production exploit.
- **Packed dynamic ABI collisions:** Rejected as likely textbook material; no fresh, primary-source incident was verified within the budget.
- **EIP-1884 and transfer liveness:** Rejected as likely known; no separate primary incident was verified. The retained transient-storage question covers a different stipend assumption.
- **Custom errors and require with an error:** Rejected because syntax/version recall lacks verified incident backing in this pass.
- **Memory-safe assembly annotations:** No exact annotation-related incident was verified; do not replace that missing evidence with the unrelated 2022 assembly optimizer bug.
- **Uniswap v3 Multicall fix:** The source page was opened, but this pass did not verify a specific fixing commit or disclosure. The retained candidate uses the verified MISO/Opyn account instead. https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol

Research used 40 web opens or search queries, counting each URL or query separately. Twelve candidates remain; three have high estimated frontier-failure confidence. None has passed cold-model calibration. Only this output file was written.
