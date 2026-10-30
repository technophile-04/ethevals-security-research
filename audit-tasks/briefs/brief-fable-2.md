# Fable advisor, round two: every model finds our audit bugs. What changes next?

You advised on the framing earlier. Your answer is /tmp/subagents/security-audit-tasks/fable-advice.md and the plan is in "/Users/shivbhonde/Documents/shiv/1. Projects/ethevals/security-audit-tasks-plan.md". Read both, then the facts below. Research and judge only. Write no code.

## What Shiv decided after your first answer

- Don't copy contest repos as they are, because an agent with the web could find the original. Each task is our own protocol carrying a real finding's mechanism, under new names.
- Pillar is Build, in the security domain. Tasks run only in the internet mode (no offline mode).
- Start small and avoid bloat. Light research. Volume first.

## What happened (measured, one trial per cell)

Four tasks (PR #83): staking (542 lines, 2 known vulnerabilities), governance (670, 2), vault (689, 2), dex (590, 1). An Opus or GPT writer built each one from 2025 contest findings (Kinetiq, Yeet, RAAC, BakerFi, Liquid Ron, a Zealynx AMM finding). The judge was checked first: 21 of 21 verdicts right on reference, near-miss and missing reports.

| Task | Claude Code (Opus 5.5) | Codex (GPT-6.1-sol) | DeepSeek 4.1 Flash | Kimi K3.1 |
| --- | --- | --- | --- | --- |
| staking | found all | found all | found all | found all |
| governance | found all | found all | found all | found all |
| vault | found all | found all | found all | crashed (API error) |
| dex | found all | found all | found all | found all |

- Claude: 6 to 9 tool calls per task. One read of the source, then proof tests that confirmed. Each bug appears right after the single read.
- Codex: 13 to 18 tool calls. Rereads and runs the stock tests, but each bug appears before its own tests.
- No frontier trajectory searched the web or looked up the original findings. Open-model trajectories are not read yet.
- DeepSeek cost $0.04 to $0.14 a trial.
- Then option B: vault grown to 1,225 lines (roles, timelock, guardian, rebalance, management fee, an Aave v3 strategy). Same two bug lines byte-for-byte. The README no longer states the properties the bugs break. Result: Claude Code found both (378 s, was 164 s). DeepSeek found both (710 s, $0.15).
- The bugs are single-function accounting slips: `undeploy` forgets to lower `deployedAssets`, `totalAssets` doesn't subtract `accruedFees`, `harvest` doesn't subtract `totalQueued`, `cancel` doesn't cancel in the timelock, `exitEarly` writes no checkpoint, fee collection doesn't lower `trackedBalance`.
- Context: EVMbench (whole Code4rena repos, median 1,296 lines, offline) measured best detect recall at 45.9% (Opus 4.6, March 2026).

## Questions

1. Why does every model, the cheapest included, find these? Name the likely cause or causes. Weigh: the size, the bug type (one missing line in one function), bugs written by a model being the kind a model sees, the README, the instruction saying "audit", internet mode.
2. What single change would most likely produce a measured open-model miss, with frontier agents finding it only with work, without tricks or puzzles (Shiv rejected those) and within Shiv's calls above? Rank at most three options, and say what each costs.
3. Should these four tasks stay in PR #83 as easy baseline tasks, be reworked, or be dropped? One line.
4. What would make you stop and say the audit form can't separate models at task sizes we can afford?

Answer before reading any other note. Then be blunt. Write to /tmp/subagents/security-audit-tasks/fable-advice-2.md, under 900 words. Your last message is a five-line summary.
