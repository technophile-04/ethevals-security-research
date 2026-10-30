# Brief: round two, behaviour questions proved by execution

Read /tmp/subagents/security-quizzes/brief.md first for the shared rules: quiz form, the answer line, no greeting, no eval words, under 130 words including code, incident backing where it exists, write the output file incrementally. This brief replaces the "what survives" section there.

## What round one taught us

84 questions about Ethereum spec facts (EIP-7702 nonce rules, ERC-7739 digests, EntryPoint v0.7 postOp accounting, Permit2 lockdown, Safe domain fields, OpenZeppelin 5.x initializers, ERC-4626 virtual shares, Chainlink circuit breakers, Fusaka gas caps) were asked cold to Claude Opus 5.5 and GPT-6.1 at high reasoning. Both answered every one correctly. Recalling facts, however obscure, no longer separates models.

Exactly one question caught both of them. It showed this code and asked whether the first write survives `save(true)` under Solidity 0.8.16 via-IR optimized:

```solidity
uint256 public saved;
function save(bool finish) external { saved = 1; finishEarly(finish); saved = 2; }
function finishEarly(bool finish) internal { if (finish) { assembly { stop() } } }
```

Both models answered "no, the 0.8.13 to 0.8.16 storage-write-removal bug deletes it". Compiling and running shows `saved == 1`: the helper gets inlined, and the Solidity disclosure itself says inlined helpers are unaffected. The models recognised a famous shape and stopped reading. The code's real behaviour differed from what its shape suggests.

## The ask

Write 10 to 12 questions where the code's actual behaviour, proved by running it, differs from what a reader who recognises the shape would predict. Three shapes:

1. **The shape predicts a problem; the behaviour is fine.** The code resembles a well-known mistake (ordering of state update and external call, storage layout mismatch, a cached domain separator, a first-deposit rounding issue, a compiler bug, selfdestruct, an unchecked return) but behaves correctly because of one specific, checkable detail: a compiler version or optimizer rule, a modifier on the path that matters, EIP-6780, an OpenZeppelin check the reader forgets, a nonce the reader does not see. Answer: the write survives, the second call reverts, the share count is what it should be.
2. **The shape predicts safety; the behaviour has a gap.** The code uses the textbook guard (nonReentrant, SafeERC20, virtual shares, a staleness check, a two-step owner transfer, an initializer modifier, a low-s check) but the guard does not cover this call path: two contracts sharing a transient lock, a decimals offset of zero, a check on the wrong feed, a reinitializer version, a delegatecall route. Answer: the second call succeeds, the balance ends at X, initialize can be called again.
3. **Exact outcome.** A share-math, rounding, or gas scenario with concrete numbers where the answer is a number, and a reader who knows the direction still has to compute it. Answer with the number only.

Phrase every question as a reviewer asking what the code does: "After these calls, what does `saved` hold?", "Does the second deposit revert?", "How many shares does Bob receive?". Do not use the words attack, attacker, exploit, drain, steal, vulnerable, or bypass anywhere; describe behaviour and outcomes.

## Predict first, then run

For each candidate, before you run anything, write down what you expect the outcome to be from reading the code. Then write a Foundry test that pins the compiler with `solc = "x.y.z"` in foundry.toml, sets via_ir and optimizer as the question states, and asserts the real outcome. Run `forge test`. Keep every candidate where your prediction was wrong; those are the ones that matter. Keep a candidate where your prediction was right only if you can name a specific detail a careful reader would miss. Record under **Verified by:** the exact command, the pass line, and under **Predicted:** what you expected before running. No fork tests, no network calls from tests. Foundry is installed; solc versions download on first use. Put each test under /tmp/subagents/security-quizzes/pilot/<slug>/. Some directories from an earlier attempt already exist there; reuse or ignore them.

Do not reuse any topic in /tmp/subagents/security-quizzes/asked-slugs.txt. Keep the instruction honest: no words that hint at a twist, no "note that", no "carefully".

Write your candidates in the layout from brief.md plus the Predicted and Verified by lines, to the output file named in your task. Your last message: how many candidates, how many of each shape, how many where your own prediction was wrong, and the three you think are strongest.
