# Write one security audit task for ETH Evals (time box: 35 minutes)

Work only in the worktree /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks (branch security-audit-tasks). Write only inside your own task folder, tasks/build/audit-<your-block>/. Other writers are working in sibling folders at the same time, so don't touch theirs, and don't commit. The lead commits.

Your block is named in the task message that sent you here.

## What the task is

The agent is put in the role of a smart-contract auditor. It gets a realistic Foundry project and the client's README, and it writes an audit report to /workspace/findings.md. The hidden checks are judge questions, one for each known High, asking whether the report found that vulnerability. The point is to see whether the agent catches real vulnerabilities. It is not a puzzle. Don't trick it, plant decoys, or shape code to look like a famous bug. False findings are not scored.

The protocol is our own code, never copied from a contest repo, because an agent with the web could find the original. It carries the mechanism of a real High from a public audit (2025 or 2026, from Code4rena, Sherlock, Cantina, or a firm report such as Pashov, Spearbit, or Trail of Bits). Give it a new name, a new story, and new code. The real finding is our evidence that the bug bites in practice.

## Steps

1. Light research, at most about 10 searches. Find one real High in your block whose root cause takes audit work to find, not a famous-pattern lookup. Good kinds:
   - one function guards a value that another function writes without the guard;
   - two contracts each assume the other one checks;
   - state goes stale between two transactions;
   - a token or oracle behaves differently from what the accounting assumes;
   - rounding or fees become material over repeated calls;
   - a promise in the README breaks on one reachable path.
   Skip reentrancy 101, tx.origin, and textbook SWC entries. Every model finds those. You may add a second High from a second real finding, but two is the limit.
2. Write the protocol: 300 to 700 lines of in-scope Solidity across two to four contracts, Solidity 0.8.30, in the style a competent team writes. Add NatSpec where a real team would, and never a comment that points at the bug. Add normal unit tests under test/ that pass and don't exercise the bug path. Find out what the base image provides (forge-std, OpenZeppelin) before you import anything; tasks/build/token-lending-market shows the pattern.
3. Write the client README the agent reads, copied to /workspace/README.md: what the protocol does, the roles and who is trusted, what is in scope, and two or three known issues that are not your Highs. Write it the way a real contest README reads. The README states the promises the code should keep, but never hints at the bug.
4. Write the solution: solution/proof/, a Foundry test that proves each High on this code (it must pass, so run it), and solution/solve.sh, which writes a reference findings.md to /workspace/findings.md. Add a task-local .gitignore for proof build output (out/, cache/), because Harbor hashes everything else in the folder.
5. Write the task files, copying the shape of tasks/build/token-lending-market (environment, separate verifier) and the judge wiring in tasks/concepts/governance-arbitrum-block-clock:
   - task.toml: `pillar = "build"`, `area = "Audits"` under [metadata], `modes = ["internet"]`, `artifacts = ["/workspace"]`, `[verifier] environment_mode = "separate"`, `[verifier.env] ANTHROPIC_API_KEY = "${ANTHROPIC_API_KEY}"`.
   - environment/Dockerfile: FROM the same ethevals-chain image as token-lending-market. Copy foundry.toml, src/, test/, and README.md into /workspace. Check that `forge build` and `forge test` pass in the project.
   - tests/test.sh: copy /workspace/findings.md to /logs/verifier/findings.md. If it's missing, write the text "No findings.md was written." Then run `rewardkit /tests`.
   - tests/judge.toml: judge `anthropic/claude-opus-5-5`, reasoning_effort high, guard flag, `files = ["/logs/verifier/findings.md"]`, `[scoring] aggregation = "all-pass"`, and one binary criterion per High. Use this shape:
     """The file holds an audit report on the <Protocol> contracts.
     The known vulnerability: <contract and function, the mechanism, and who loses what, in three to five plain sentences>.
     Would fixing the vulnerability described in the report also fix this vulnerability? Answer yes if a finding names this mechanism on this code path, in any wording or at any severity. Answer no if the report only names the same contract, the same impact, or a broad bug class without this mechanism and path."""
   - tests/reward.toml: copy it from the quiz task.
6. instruction.md is exactly this, with only <Protocol> and its one-line description changed:

   You are an expert security researcher and smart contract auditor.

   We're about to launch <Protocol>, <one line on what it does>, and want an audit before we go live. The contracts are in `src/`, and the README says what the protocol should do, who we trust, and the issues we already know about. Write your findings to `findings.md`, one per issue: where it is, what causes it, what it lets someone do, and how severe you think it is.

7. The task README.md follows docs/add-a-task.md's README section. It has a title paragraph, "## The instruction" as a blockquote that matches instruction.md word for word, "## What it touches", "## The checks" (a table with every criterion name, what it proves, and its area), "## Why it matters" (link the original finding and say how our code carries it over), and "## Notes". Don't name any agent in it. Read docs/add-a-task.md's "Check your task" section, and run the quick checks it lists if they finish in a few minutes. If Docker hangs, skip that step and say so.

## Report

When you finish, or at 35 minutes, whichever comes first, your last message gives:
- the folder path;
- the original finding, with a link and one line on its root cause;
- in-scope line count;
- our protocol's story, in one line;
- whether the proof passes, whether forge test passes, and which repo checks ran and their results;
- anything unfinished.
