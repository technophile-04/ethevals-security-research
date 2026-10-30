# Read how frontier agents found the bugs in four audit tasks (time box: 20 minutes)

Four security audit tasks live in /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks/tasks/build/: audit-staking, audit-governance, audit-vault and audit-dex. Each one asks an agent, in the auditor role, to audit a Foundry project and write findings.md. A judge checks whether the report names each known High; those criteria are in tests/judge.toml. Read-only: don't edit anything.

Trajectories are at results/local-frontier/<lane>/jobs/*/audit-*/agent/trajectory.json under that worktree. The lanes are given in the message that sent you here. Each row in <lane>/rows.jsonl has the verdicts and working_seconds.

For each trajectory, answer:
- Tool calls in total, and how many files it read (and which ones it read twice).
- Did it run forge build or forge test? Did it write and run its own test or proof of a bug? Did it fix anything after a failed run?
- Did it search the web or fetch any URL? List the URLs and queries. Flag anything that looks for the original public finding or for a contest report.
- At which step did each known High first appear in its thinking or notes: on the first read of the file, or after a test?
- What else did it report: count of findings, and any finding that is wrong about the code (one line each).
- One line: did it find the Highs by reading alone, or did it need testing to confirm them?

Then a short verdict per task. Use "too easy for this agent" when it found every High on a first read with no testing. Use "needed work" when it needed testing or rereading, or when it missed a High.

Write the report to /tmp/subagents/security-audit-tasks/trajectories-<lanes>.md (the name is given in your task message), under 900 words. Your last message is a five-line summary.
