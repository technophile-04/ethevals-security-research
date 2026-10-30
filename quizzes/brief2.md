# Brief: round two, trap questions verified by execution

Read /tmp/subagents/security-quizzes/brief.md first; everything there still holds (quiz form, answer line, no greeting, no eval words, under 130 words including code, auditor framing, incident backing, write incrementally).

## What round one taught us

84 security questions about spec facts (EIP-7702 nonce rules, ERC-7739 digests, EntryPoint v0.7 postOp, Permit2 lockdown, Safe domain fields, OpenZeppelin 5.x initializers, ERC-4626 virtual shares, Chainlink circuit breakers, Fusaka gas caps, and more) were asked cold to Claude Opus 5.5 and GPT-6.1 at high reasoning. Both answered every one correctly. Spec facts, however obscure, do not catch frontier models any more.

Exactly one question caught both of them. It showed this code and asked whether the first write survives `save(true)` under Solidity 0.8.16 via-IR optimized:

```solidity
uint256 public saved;
function save(bool finish) external { saved = 1; finishEarly(finish); saved = 2; }
function finishEarly(bool finish) internal { if (finish) { assembly { stop() } } }
```

Both models answered "no, the storage-write-removal bug (0.8.13 to 0.8.16) deletes it". Compiling and running it shows `saved == 1`: the helper gets inlined, and the Solidity disclosure itself says inlined helpers are unaffected. The models recognised the famous bug's shape and stopped reading.

## The ask

Write 12 candidates that work the same way, each verified by actually executing code, and each still a question a working auditor would ask about realistic code. Three shapes, roughly four each:

1. **Looks vulnerable, is not.** Code that has the shape of a famous bug (reentrancy order, storage collision, signature replay, inflation attack, compiler bug, selfdestruct, unchecked call, tx.origin) but is safe because of one specific, verifiable detail: a version behaviour, an optimizer rule, a modifier on the callback path, EIP-6780, an OpenZeppelin check the model forgets, a nonce the model does not see. The model's pattern memory says "vulnerable". The answer is "no".
2. **Looks safe, is not.** Code that uses the textbook mitigation (nonReentrant, SafeERC20, virtual shares, a staleness check, a two-step owner transfer, an initializer modifier, a low-s check) but the mitigation does not cover this case: two contracts sharing a transient lock, an offset of zero, a check on the wrong feed, a reinitializer version, a delegatecall path. The model's pattern memory says "safe". The answer is "yes, exploitable" or the specific consequence.
3. **Exact outcome.** A share-math, rounding, or gas scenario with concrete numbers where the answer is a number the model must compute, and most models get the direction right but the number wrong. Answer with the number only.

## Verification is the point

For every candidate, write a Foundry test under /tmp/subagents/security-quizzes/pilot/<slug>/ that proves the answer: pin the compiler with `solc = "x.y.z"` in foundry.toml, set via_ir and optimizer as the question states, and assert the outcome. Run `forge test`. Record the exact command and the pass line in the candidate under a new field **Verified by:**. No fork tests, no network calls from tests; everything runs locally. If you cannot prove a candidate by execution, drop it and list it under Rejected. Foundry is installed; solc versions download on first use.

Do not reuse any topic in /tmp/subagents/security-quizzes/asked-slugs.txt. Avoid reentrancy 101 and tx.origin unless the trap is the point. Keep the instruction honest: no words that hint at a trap, no "note that", no "carefully".

Write to /tmp/subagents/security-quizzes/pilot.md in the layout from brief.md plus the Verified by line. Your last message: how many candidates, how many of each shape, and the three you think are strongest.
