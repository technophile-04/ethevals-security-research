# Currency check

Checked 2026-10-30 IST, with 40 fetch or search attempts, including failed requests and retries. Latest releases checked: [Solidity 0.8.38](https://github.com/argotorg/solidity/releases/tag/v0.8.38), released October 22, and [OpenZeppelin Contracts 5.7.0](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v5.7.0), released July 29. Other baselines are EntryPoint v0.8.0, Permit2 main, and Safe v1.5.0.

“Holds today” asks whether the stated answer survives moving to these baselines. Older pinned questions retain their historical answers. This was a source check; I did not rerun the proofs. The conditional-stop block is in `evm.md`, rather than the three named input files.

### accounts-7739-typeddatasign-domain

- **Holds today?** yes. The dapp's domain remains outside; the account's domain fields sit inside `TypedDataSign`. In [5.7.0's ERC7739Utils](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.7.0/contracts/utils/cryptography/draft-ERC7739Utils.sol#L117), the helper accepts `domainBytes`; lines 158–160 place the account fields in the signed structure. The 5.7.0 release changes descriptor validation, not this structure.
- **Incident link real?** [Alchemy](https://www.alchemy.com/blog/erc-1271-signature-replay-vulnerability) exists and supports the 2023 replay disclosure; it does not establish ERC-7739's later format or the full blind-signing history.
- **Plain words:** This tests which contract's identity surrounds the signature when one contract checks a signature for another.

### accounts-1271-permit2-cross-account-replay

- **Holds today?** yes, for the exact account implementation shown. [PermitHash.sol on main, lines 11–12 and 37–40](https://github.com/Uniswap/permit2/blob/main/src/libraries/PermitHash.sol#L11), omits the owner from `PermitSingle`. Equal starting nonces and the same signing key permit the replay. No prior token approval is needed to set the allowance, although spending also needs token approval to Permit2.
- **Incident link real?** [Alchemy](https://www.alchemy.com/blog/erc-1271-signature-replay-vulnerability) and [Trail of Bits, section 4](https://blog.trailofbits.com/2026/03/11/six-mistakes-in-erc-4337-smart-accounts/) exist and support cross-account signature replay; neither establishes an actual theft here.
- **Plain words:** This tests whether one signature can authorize spending from two contracts owned by the same person.

### signatures-permit2-signaturetransfer-frontrun

- **Holds today?** yes. [PermitHash.sol on main, lines 59–62](https://github.com/Uniswap/permit2/blob/main/src/libraries/PermitHash.sol#L59), hashes `msg.sender` as the spender. A direct call from the searcher cannot use the vault's signature. This conclusion does not cover unsafe public functions in the vault itself.
- **Incident link real?** [Puffer #28702](https://reports.immunefi.com/puffer-finance/28702-sc-insight-malicious-users-can-frontrun-permits-to-dos-swaps) exists and alleges EIP-2612 permit griefing, not Permit2 SignatureTransfer theft; the backing names ZeroLend #29244 but supplies no URL for it.
- **Plain words:** This tests whether copying a signature lets a stranger use it through a different contract or account.

### signatures-oz-ecdsa-signature-as-key

- **Holds today?** yes, for changing the bytes of the one supplied signature. [ECDSA.sol 5.7.0, line 65](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.7.0/contracts/utils/cryptography/ECDSA.sol#L65), requires 65 bytes; line 185 rejects high `s`. This does not prevent a signer from creating another valid signature for the same message. Lines 46–48 warn that the length restriction is deprecated and will disappear in 6.0.
- **Incident link real?** [GHSA-4h98-2769-gh6h](https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-4h98-2769-gh6h) exists and describes this exact replay-protection pattern; affected versions are 4.1.0–4.7.2, fixed in 4.7.3. GitHub dates the advisory August 10, 2022, rather than August 18. It is a disclosure, not evidence of an exploit.
- **Plain words:** This tests whether a user can change one signature's form to claim the same payment twice.

### accounts-4337-unused-gas-penalty

- **Holds today?** yes for the five-million limit in the question. [EntryPoint v0.8.0, lines 44–47](https://github.com/eth-infinitism/account-abstraction/blob/v0.8.0/contracts/core/EntryPoint.sol#L44), sets 10% and a 40,000 threshold. Lines 948–955 waive the penalty when unused gas is at most 40,000; otherwise they charge 10% of all unused gas. The approximate 485,000 penalty remains valid; the threshold is not subtracted first.
- **Incident link real?** [Osec's URL](https://osec.io/blog/2025-12-02-paymasters-evm) redirects to a live article that supports the SEND undercharging pattern and bundler profit; it also says SEND's own bundler contains that risk. It reports no realized loss.
- **Plain words:** This tests whether a contract that pays users' fees also pays for an excessive unused allowance.

### compiler-legacy-init-order

- **Holds today?** yes with the specified legacy pipeline, including 0.8.38. [The current compiler documentation, lines 19–35](https://docs.soliditylang.org/en/latest/ir-breaking-changes.html), puts all legacy state initializers before the constructors and describes the different via-IR order. This is a pipeline difference, not a fixed compiler bug. The zero-address answer does not apply to via-IR.
- **Incident link real?** The [documentation](https://docs.soliditylang.org/en/latest/ir-breaking-changes.html#state-variable-initialization-order) exists and supports the behavior; no named incident. One search found no matching audit finding or disclosure; none found.
- **Plain words:** This tests whether a contract reads its owner before the compiler runs the code that sets that owner.

### compiler-tuple-assignment-self-transfer

- **Holds today?** yes for 0.8.38's implementation. [Legacy TupleObject::storeValue, lines 614–618](https://github.com/argotorg/solidity/blob/v0.8.38/libsolidity/codegen/LValue.cpp#L614), writes right to left. [The via-IR writer, lines 3205–3211](https://github.com/argotorg/solidity/blob/v0.8.38/libsolidity/codegen/ir/IRGeneratorForStatements.cpp#L3205), also reverses the components. The final balance is 60. This order is an implementation detail, not a promised language rule.
- **Incident link real?** [SolidityScan](https://blog.solidityscan.com/super-sushi-samurai-hack-analysis-ae96b76a6252/) exists and supports Super Sushi Samurai's self-transfer inflation and roughly $4.8 million loss; it does not support this tuple form or its opposite, balance-reducing result.
- **Plain words:** This tests whether sending tokens to yourself can reduce your balance because the contract writes the same balance twice.

### evm-try-catch-empty-return

- **Holds today?** yes. [Solidity 0.8.38's documentation source, lines 132–134](https://github.com/argotorg/solidity/blob/v0.8.38/docs/control-structures.rst#L132), retains the code-check omission since 0.8.10. Lines 898–900 say return-data decoding failures escape `catch`. An empty result cannot supply the expected `bytes4`.
- **Incident link real?** No named incident or backing URL. One search found [a Solidity forum disclosure](https://forum.soliditylang.org/t/what-solidity-try-catch-actually-catches/3705) of uncaught return-data decoding failures; it supplies no named lending-market loss or audited instance of this exact hook.
- **Plain words:** This tests whether a borrower can block the contract's debt collection by choosing an account that returns no answer.

### forwarder-multicall-suffix-oz5

- **Holds today?** yes. [Multicall.sol 5.7.0, lines 16–19](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.7.0/contracts/utils/Multicall.sol#L16), dates the protection to 4.9.4 and 5.0.1. Lines 27–33 append the real caller's context to each call, so the stranger fails the owner check.
- **Incident link real?** [OpenZeppelin's disclosure](https://www.openzeppelin.com/news/arbitrary-address-spoofing-vulnerability-erc2771context-multicall-public-disclosure) exists and supports the old spoofing pattern, thirdweb's report, and the listed 84.59 ETH and 17,394 USDC losses; those losses do not describe patched 5.x behavior.
- **Plain words:** This tests whether a stranger can pretend to be the owner when a contract runs several calls together.

### upgrades-stateless-parent-gap

- **Holds today?** only on the older gap-based 4.x layout shown, confirmed at 4.9.6. [MulticallUpgradeable 4.9.6, line 51](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v4.9.6/contracts/utils/MulticallUpgradeable.sol#L51), declares `uint256[50] private __gap`. The stated 201-to-251 shift belongs to that inheritance layout. It does not transfer to 5.x, whose [upgradeable contracts use namespaced storage](https://docs.openzeppelin.com/contracts/5.x/upgradeable). A direct 4.x-to-5.x upgrade is a separate compatibility problem.
- **Incident link real?** The [4.9.6 source](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v4.9.6/contracts/utils/MulticallUpgradeable.sol) exists and supports the hidden 50-slot allocation; no named incident. One search found no matching audit finding or disclosure; none found.
- **Plain words:** This tests whether adding a seemingly empty parent contract during an upgrade can make recorded balances disappear.

### evm-transfer-refund-to-safe

- **Holds today?** yes for the stated active standard Safe, also supported by 1.5.0's receive path. [SafeProxy 1.5.0, lines 42 and 63](https://github.com/safe-global/safe-smart-account/blob/v1.5.0/contracts/proxies/SafeProxy.sol#L42), reads the singleton and delegates. [Its receive function, lines 14–15](https://github.com/safe-global/safe-smart-account/blob/v1.5.0/contracts/common/NativeCurrencyPaymentFallback.sol#L14), only emits the receipt event. Both accesses are warm during the refund. This is a code-based conclusion; I did not measure 1.5.0's gas or carry forward the proof's exact 1,841 figure.
- **Incident link real?** The [supplied Safe help URL](https://help.safe.global/en/articles/40813-why-can-t-i-transfer-eth-from-a-contract-into-a-safe) returned 404 in the web fetch; I could not verify its claimed wording. Tagged code supports the mechanism, not the missing article.
- **Plain words:** This tests whether a contract can refund a wallet while that same wallet is already running a purchase.

### compiler-transient-clear-collision

- **Holds today?** only on Solidity 0.8.28–0.8.33 with via-IR and Cancun or later, when matching clearing helpers collide. The [Solidity blog, lines 8–14](https://www.soliditylang.org/blog/2026/02/18/transient-storage-clearing-helper-collision-bug/), gives that exact range and fixes it in 0.8.34. Solidity 0.8.38 is unaffected. The blog also says which location gets cleared depends on code-generation order; the particular Bob outcome requires the shown source and compilation setup.
- **Incident link real?** The [disclosure](https://www.soliditylang.org/blog/2026/02/18/transient-storage-clearing-helper-collision-bug/) exists at the `www.soliditylang.org` host and supports the collision; the latest released [bugs.json](https://github.com/argotorg/solidity/blob/v0.8.38/docs/bugs.json) agrees. The disclosure reports three matching deployed contracts and mitigations, not an exploit or this exact ownership example.
- **Plain words:** This tests whether a compiler mistake lets a former owner regain control after giving it up.

### compiler-memory-bytes-delete

- **Holds today?** only on the legacy evmasm pipeline in every released Solidity version through 0.8.36. The [Solidity blog, lines 10–12](https://www.soliditylang.org/blog/2026/09/10/memory-byte-array-element-delete-clears-whole-word-bug/), says the defect predates the first release and fixes it in 0.8.37. Via-IR is unaffected; optimization does not matter. Solidity 0.8.38 keeps Alice's recipient address.
- **Incident link real?** The [disclosure](https://www.soliditylang.org/blog/2026/09/10/memory-byte-array-element-delete-clears-whole-word-bug/) exists at the `www.soliditylang.org` host and supports the whole-word overwrite; the latest released [bugs.json](https://github.com/argotorg/solidity/blob/v0.8.38/docs/bugs.json) agrees. The blog says no deployed contract is known to be affected, rather than merely reporting no known exploit.
- **Plain words:** This tests whether clearing one byte with an older compiler can also erase the payment recipient beside it.

### evm-compiler-conditional-stop

- **Holds today?** only on Solidity 0.8.13–0.8.16 with the Yul optimizer and the triggering conditional termination pattern. The [Solidity security alert](https://www.soliditylang.org/blog/2022/09/08/storage-write-removal-before-conditional-termination/) gives the introduction in 0.8.13 and fix in 0.8.17. The latest released [bugs.json entry SOL-2022-7](https://github.com/argotorg/solidity/blob/v0.8.38/docs/bugs.json) agrees. The shown optimized via-IR case qualifies; 0.8.38 preserves the first write when execution stops there.
- **Incident link real?** The [alert](https://www.soliditylang.org/blog/2022/09/08/storage-write-removal-before-conditional-termination/) exists and supports the compiler defect, affected range, and fix; it does not establish a production loss.
- **Plain words:** This tests whether an older compiler can erase a saved value when a contract stops before its next write.
