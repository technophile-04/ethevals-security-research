# Check the round-two judges before trials (time box: 15 minutes, spend cap: $2)

Same method as /tmp/subagents/security-audit-tasks/judge-check/report.md. Read it, and reuse its scripts in /tmp/subagents/security-audit-tasks/judge-check/. Work in /tmp/subagents/security-audit-tasks/judge-check-2/. Don't edit anything inside the task folders.

Task: the folder named in your task message, under /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks/tasks/build/. Its tests/judge.toml has new criteria, one per known vulnerability. Each vulnerability is a mismatch between two pieces of code.

Reports to run:
- reference: the findings.md that solution/solve.sh writes. Every criterion should say yes.
- per criterion, a half-only near miss. It names one half of the mismatch and the right harm, but not the other half or how they combine. That criterion should say no.
- per criterion, a same-harm near miss. It names a different known vulnerability in this task, or a different mechanism with the same harm. That criterion should say no.
- missing: "No findings.md was written." Every criterion should say no.

Report in /tmp/subagents/security-audit-tasks/judge-check-2/report-<task>.md: a table with report, criterion, verdict, expected and a one-line reason. Then list the misgrades and, for each, proposed criterion wording (don't apply it). Your last message is a five-line summary with the misgrade count and spend.
