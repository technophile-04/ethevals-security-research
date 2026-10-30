# Researcher 2: the core principles in auditors' agent skills

Read /tmp/subagents/security-audit-tasks/context.md first.

Audit firms now publish "skills" (instruction files for AI agents) that write down how they audit. Shiv named two by voice as "pesto" and "canto". "pesto" is most likely Pashov Audit Group (github.com/pashov/skills). "canto" is unclear: check whether Cantina (cantina.xyz) publishes an agent skill or a written audit method; if you cannot find one in a few searches, say so and use Trail of Bits (github.com/trailofbits/skills) as the second source instead. Cyfrin (github.com/Cyfrin/solskill) only if the first two leave a gap.

Question: what are the core principles these skills teach an auditor agent, and which of them tell us what an audit task should test?

Answer, with quotes and links to the exact files:
- The method: the steps the skill makes the agent take (for example: map the protocol, find trust boundaries, write invariants, walk each function, check known attack vectors). Name each step in one line.
- The bug classes or attack-vector lists they carry, and how they rank or prioritise them. Summarise; do not copy whole lists.
- What a finding must contain in their report format (location, root cause, impact, severity, proof).
- Which principles a model would skip or get wrong if it just pattern-matched code. That is the part that tells us which vulnerabilities need real audit work to find, as opposed to a famous-pattern lookup.

End with "Principles worth building tasks around" (at most six bullets, each one line saying what kind of vulnerability it points to) and "What these skills say models already do well" if they say it.

Write the report to /tmp/subagents/security-audit-tasks/research-skills.md. Your last message is a five-line summary.
