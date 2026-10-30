# Researcher 1: how agentic audit benchmarks frame the job

Read /tmp/subagents/security-audit-tasks/context.md first.

Question: when a benchmark asks an AI agent to audit smart contracts and grades whether it found the real vulnerabilities, how is the job framed and graded? We want the core patterns, not a survey.

Look at, in this order, and stop once the answers are clear:
1. EVMbench (openai/frontier-evals, project/evmbench), detect mode first, exploit and patch modes briefly.
2. Anthropic's smart-contract exploit work (SCONE-bench or similar, 2025-2026), if it exists; skip if not found in a few searches.
3. How audit contests (Code4rena, Sherlock, Cantina) hand a codebase to auditors: the scope, the README, known issues, severity rules. Only what matters for framing a task.
4. One or two others only if they add a pattern the first three lack.

Answer, with quotes and links:
- The exact instruction text the agent gets (quote it), and what the environment holds: whole repo or excerpt, size in lines, tests, docs, tools.
- Where the ground truth comes from (real contest findings? planted bugs?) and why.
- How a finding is graded: what counts as "found" (location, root cause, impact), who judges, partial credit, whether only High/Medium count.
- What the published results say frontier models miss, and why (codebase size, cross-contract reasoning, protocol intent, something else).
- How, if at all, they handle false findings, in one or two lines.
- The difference you see between this framing and a CTF puzzle.

End with "Patterns worth taking" (at most six bullets) and "Patterns to avoid" (at most three).

Write the report to /tmp/subagents/security-audit-tasks/research-benchmarks.md. Your last message is a five-line summary.
