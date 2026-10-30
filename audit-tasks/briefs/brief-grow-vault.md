# Grow audit-vault to a real protocol size (time box: 40 minutes)

Work only in /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks/tasks/build/audit-vault/ (branch security-audit-tasks). Don't commit. The lead commits.

## Why

The task gives an agent, in the auditor role, the Sluice USDC vault: about 690 lines with two known Highs. Every agent found both Highs in one trial each: Claude Code, Codex, and even DeepSeek 4.1 Flash, the cheapest model. In 600 lines a single careful read finds them. In EVMbench, whole contest repos (median 1,296 lines) brought frontier recall down to 46%. This is a one-task experiment. Change the size and nothing else, then trial it.

## What to change

1. Grow the in-scope Solidity in environment/src/ to 1,200 to 1,500 lines. Add the features a production USDC vault over lending strategies really has. For example:
   - a second strategy type
   - an allocator role with per-strategy caps and a rebalance
   - a withdrawal queue order the curator sets
   - ERC-4626 max* limits and a deposit cap
   - a guardian who can pause
   - a timelock on fee and strategy changes
   - a management fee next to the performance fee
   - the events a team would emit

   Pick what fits. No filler, no dead code, and nothing shaped to distract. Every feature must work. Cover it with normal unit tests under environment/test/ that pass and don't exercise either known High's path.
2. Keep both known Highs exactly as they are: `BaseStrategy.undeploy` never lowers `deployedAssets`, and `SluiceVault.totalAssets` counts unclaimed `accruedFees`. Don't make either bug line stand out more or less than it does now. If a rename or a moved function changes how the judge criteria in tests/judge.toml name the code path, update the criteria to match, and keep their wording otherwise.
3. Rewrite the client README (environment/README.md) the way a real client writes one: what it does, the roles and who is trusted, the scope, and a few known issues that are not the Highs. Remove any sentence that states the exact property either High breaks. Describe the features without promising the invariant the bug violates.
4. Keep the Foundry proof in solution/proof/ passing against the new code. Update solution/solve.sh's reference findings.md to the new names. Update the task README.md: line count, "What it touches", the checks table, and Notes. Note there that this is the grown version and why. Don't change instruction.md.
5. Check it all:
   - `forge build` and `forge test` in the project, and the proof, both on the Mac and inside the task's Docker image (see the existing Dockerfile)
   - `uv run ethevals lint --tasks tasks/build/audit-vault`
   - `uv run pytest -q runner/tests/test_harbor.py`
   - after reading runner/README.md's maintainer-check notes, `uv run ethevals free-check` for this task if it finishes in a few minutes

## Report

Your last message gives:
- the in-scope line count, per file
- what you added, one line per feature
- whether both Highs' lines are unchanged, and any criterion wording you changed
- the check results
- anything unfinished
