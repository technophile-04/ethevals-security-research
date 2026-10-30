# Brief: round four, judge-graded decoy questions

Read /tmp/subagents/security-quizzes/brief.md (shared rules) and /tmp/subagents/security-quizzes/brief4.md (judge mechanics: ADR 0016, judge criterion, hand cases, Verified by). This brief changes only the shape of the question.

## Why this shape

Six judge-graded questions built from isolated Code4rena findings were answered correctly by every current model: when a snippet contains one thing, the one thing is the bug. What has caught models in this project, every time, is code that looks like a famous problem and is not: a snippet shaped like the 0.8.16 storage-write-removal bug that the inliner makes harmless beat Opus 5.5, GPT-6.1, Kimi and GLM; "looks malleable but OpenZeppelin 5.x rejects the twin" and "looks front-runnable but Permit2 binds the caller" caught the open models. Models recognise a shape and stop reading.

## The ask

Write six judge-graded questions, each a snippet of 12 to 25 lines (one or two contracts) that contains two things:

1. **A decoy**: a textbook smell that is provably harmless in this code. Examples of the kind, not a list to copy: an external call before a state update where the only reachable callee cannot re-enter (a plain ERC-20 with no hooks, pinned); an `unchecked` block guarded by a prior `require`; a `transfer` to an address that is provably warm; a `delegatecall` into an immutable implementation with a matching layout; an `abi.encodePacked` with a single dynamic argument; a missing zero-address check on a value that is never dereferenced. Model the decoy on a published invalid or disputed finding from a contest (Code4rena, Sherlock, Cantina judging logs mark them) or on a false positive the firm reports call out.
2. **The real cause of loss**: quieter, elsewhere in the snippet, modelled on a published valid finding (High or Medium) from a firm report or a contest, with firm, report, severity and URL. Rounding direction, a second path that skips a check, initialization order, an accounting update on the wrong branch, a cached value read after it changed.

The instruction opens with "You are an expert security researcher and smart contract auditor.", pins versions where behaviour depends on them, and ends: "What is the root cause of the loss? Answer in one sentence." Under 160 words including code, since the snippet is longer than before. No words that hint at a decoy: no "note", no "carefully", no "despite".

**Judge criterion:** one binary sentence: passes if the reply names the real cause (say what must be named); fails if it names the decoy as the cause, hedges between the two, or names something not in the code.

**Hand cases:** six, as brief4 says, and one of the fails must be a confident, well-written reply that blames the decoy.

**Verified by:** a Foundry test under /tmp/subagents/security-quizzes/pilot/<slug>/ with two assertions: the decoy path cannot lose funds (show the re-entry or overflow or whatever it suggests does not happen), and the real path does. Both must pass. Record the command and pass lines.

## Rules

Same as brief4: describe behaviour and loss, not attack verbs; real sources with URLs; do not reuse topics from /tmp/subagents/security-quizzes/asked-slugs.txt or pilot-judge.md or pilot-opus.md. Write to /tmp/subagents/security-quizzes/pilot-decoy.md incrementally. Last message: the six slugs with their decoy and their real cause in a few words each, the sources, and the two you think are strongest.
