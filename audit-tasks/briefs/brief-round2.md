# Round two: plant mismatched-assumption bugs in one audit task (time box: 45 minutes)

Work only in your task folder inside /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks (branch security-audit-tasks). The folder is named in your task message. Another writer is working on a sibling folder, so don't touch it. Don't commit; the lead commits.

## Why

The task puts an agent in the auditor role on a Foundry project and asks for findings.md. A judge asks, for each known vulnerability, whether fixing a reported finding would also fix it. In round one every agent found every known vulnerability: Claude Code, Codex, Kimi, and DeepSeek 4.1 Flash for $0.04 to $0.15 a trial. That held even after the vault grew from 690 to 1,225 lines. The cause is the kind of bug. Each one was a single missing line in one variable (for example, `undeploy` never lowers `deployedAssets`). Listing every function that writes a variable exposes it in one read.

Read these first:
- /tmp/subagents/security-audit-tasks/fable-advice-2.md (why, and what to plant instead)
- your task's README.md, environment/README.md, tests/judge.toml and solution/

## What to plant

Three or four known vulnerabilities, each a mismatched assumption. Two pieces of code are each correct under their own reading, and the harm appears only when both are held at once. The test for every candidate: can each function involved pass a careful local review on its own? If one half is plainly wrong when read alone, it doesn't qualify. Examples of the shape, which you should not copy:
- a settlement that reads a snapshot another path can move;
- a strategy that assumes a balance is static while the vault treats it as live;
- two modules that each rely on the other to enforce a bound.

Source each one from a public 2025 or 2026 audit finding (Code4rena, Sherlock, Cantina, CodeHawks, or a firm report) whose root cause reads "X assumed Y", not "X forgot Z". Light research only: at most about 10 searches. Carry the pair of assumptions into our code under our names, with the surrounding context it needs. Don't just port a line.

Avoid tropes every model knows: fee-on-transfer tokens, stale Chainlink prices, `slot0` manipulation, the first-depositor share inflation, reentrancy, tx.origin, and generic rounding. No decoys, no puzzles, nothing shaped to look like a famous bug.

## What to change

1. Fix the existing known vulnerabilities in the code so they are no longer bugs. Make each fix the natural one-line correction.
2. Add the new ones by changing or adding real features. The code must stay something a competent team would ship. The vault folder is about 1,225 lines and may grow to about 1,500. The dex folder is about 590 lines and may grow to about 1,000.
3. Keep the unit tests under environment/test/ passing. Add tests for new features, and none that exercise a known vulnerability's path.
4. Client README (environment/README.md): describe new features the way a client would. Never state the exact property a known vulnerability breaks.
5. solution/proof/: one Foundry test per known vulnerability, proving the loss on this code. Run them all. solution/solve.sh writes a reference findings.md naming each one.
6. tests/judge.toml: one binary criterion per known vulnerability. Use the existing shape, and name both halves of the mismatch, the code path, and the harm. Keep the closing question: "Would fixing the vulnerability described in the report also fix this vulnerability? Answer yes if a finding names this mechanism on this code path, in any wording or at any severity. Answer no if the report only names the same contract, the same impact, or a broad bug class without this mechanism and path." Keep report_written and `[scoring] aggregation = "all-pass"`.
7. Task README.md: update "What it touches", the checks table (every criterion), "Why it matters" (link each source finding and say how our code carries the assumption pair), and Notes. Don't change instruction.md.
8. Run the checks:
   - `forge build` and `forge test`, and the proof, on the Mac and inside the task's Docker image. forge-std sits at /opt/solidity in the image; on the Mac, point FOUNDRY_REMAPPINGS at a local copy.
   - `uv run ethevals lint --tasks <your folder>`
   - `uv run pytest -q runner/tests/test_harbor.py`

   Delete any out/ or cache/ your Mac build leaves in environment/.

## Report

Your last message gives:
- the in-scope line count;
- for each known vulnerability: the source finding with its link, the two halves (function and assumption each), why each half passes review alone, and the harm;
- check results;
- anything unfinished.
