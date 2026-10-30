# Check the audit tasks' judges before any trial (time box: 20 minutes, spend cap: $3)

Four tasks are in /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks/tasks/build/: audit-staking, audit-governance, audit-vault and audit-dex. Each has tests/judge.toml, with one binary criterion per known High read from /logs/verifier/findings.md. A judge (anthropic/claude-opus-5-5, through rewardkit) answers whether fixing a reported finding would also fix that High. No judge has read a report yet.

Do not edit anything inside the task folders. Trials will read them live. Work in /tmp/subagents/security-audit-tasks/judge-check/.

1. Find out how to run rewardkit's judge locally on one tests/ folder: the repo's uv environment, `uv run rewardkit --help`, and the rewardkit skill. Copy each task's tests/ folder to a scratch folder, point the judge's `files` at a scratch findings file, drop report.py if it gets in the way, and run it with the ANTHROPIC_API_KEY from the worktree's .env (`uv run --env-file /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks/.env`). Never print the key.
2. Run three reports per task:
   - reference: the findings.md that the task's solution/solve.sh writes. Every criterion should say yes.
   - near-miss: write one yourself, for each criterion. Name the same contract and a plausible harm, but a different mechanism or a broad bug class. That criterion should say no.
   - missing: the text "No findings.md was written." Every criterion should say no.
3. Keep judge spend under $3 in total. Log every call's cost if rewardkit reports it.

Report in /tmp/subagents/security-audit-tasks/judge-check/report.md: a table with task, report, criterion, verdict, expected and one line of the judge's reason. List every misgrade. For each misgrade, propose new criterion wording, but don't apply it. Your last message is a five-line summary with the misgrade count and the spend.
