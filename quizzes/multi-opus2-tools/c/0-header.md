# Multi-issue candidates, second Opus drafter (brief6)

Ground: governance and voting, staking, auctions, bridges and cross-chain messaging, account and signature paths.
Each question is one contract with three independent issues of different kinds, each modelled on a published High or Medium finding. Severities are the published ratings, not new ratings for these reductions.
Each has a Foundry project under `/tmp/subagents/security-quizzes/pilot/multi-opus2-<slug>/`, one test per issue plus controls, run with Foundry 1.5.1 and solc 0.8.28. The `src/` file is extracted from the instruction's code block by `multi-opus2-tools/extract.py`, so the code tested is the code asked about.
Word counts use `multi-opus2-tools/words.py` (whitespace words, code fences removed). The repo stayed read only. No model trials or judge calls ran; confidence lines are predictions.

**Judge policy, the same for every question (written into each criterion):** a reply passes only if it names every listed issue. Extra lines that are hygiene or design notes with no concrete loss (events, zero-address checks, gas, custom errors, SafeERC20 for a token the setup calls standard, missing timelock, trust in a role the setup calls trusted) do not fail it. A line that claims a concrete loss or broken behaviour the code does not have fails it. A hedge on a listed issue ("might", "if X then maybe", "consider whether") counts as not naming it.

