# What auditor skills teach

Research date: 2026-10-30. Sources use pinned revisions of Pashov and Trail of Bits. Targeted Cantina searches found reports and [agent-security guidance](https://cantina.xyz/blog/ai-agent-security-engineering), but no audit-agent skill or detailed auditor method. This is a search limit, not proof of absence. I used Trail of Bits as requested.

## The method

These steps combine separate skills; neither repository mandates this exact combined sequence.

1. Map the protocol, state-changing entry points, caller privileges, and prerequisite flows. Pashov's [X-Ray](https://github.com/pashov/skills/blob/eacfc09b365d2697b83355909d0300607e596ffc/x-ray/SKILL.md) records these before threat analysis.
2. Explain each function plainly, question its assumptions, then reason backward from failure. Pashov's [auditor SOP](https://github.com/pashov/skills/blob/eacfc09b365d2697b83355909d0300607e596ffc/solidity-auditor/references/senior-auditor-sop.md) names these reasoning tools.
3. Read each block and follow callees on every path. Trail of Bits' [analysis format](https://github.com/trailofbits/skills/blob/2be6433b39e009cd2b6fd3be1895f6b1faa5af9a/plugins/audit-context-building/skills/audit-context-building/resources/ANALYSIS_FORMAT.md) requires evidence for assumptions, or "nothing found".
4. Derive global invariants and inspect every writer. X-Ray distinguishes a per-call guard from a property holding across call sequences.
5. Compare documented requirements with enforcement on every path. Trail of Bits' [compliance skill](https://github.com/trailofbits/skills/blob/2be6433b39e009cd2b6fd3be1895f6b1faa5af9a/plugins/spec-to-code-compliance/skills/spec-to-code-compliance/SKILL.md) also checks undocumented behavior.
6. Search specialist bug classes, then break assumptions without relying on named patterns. Pashov's [first-principles agent](https://github.com/pashov/skills/blob/eacfc09b365d2697b83355909d0300607e596ffc/solidity-auditor/references/hacking-agents/first-principles-agent.md) says "Do not pattern-match."
7. Trace a concrete attack through guards, reachable states, attacker actions, and victim harm. Pashov's [judging rules](https://github.com/pashov/skills/blob/eacfc09b365d2697b83355909d0300607e596ffc/solidity-auditor/references/judging.md) make these four gates.
8. Search related contracts for repeat instances and other affected branches; deduplicate by root cause. Pashov's [shared rules](https://github.com/pashov/skills/blob/eacfc09b365d2697b83355909d0300607e596ffc/solidity-auditor/references/hacking-agents/shared-rules.md) require this follow-through.

## Bug classes and priorities

Pashov's [audit skill](https://github.com/pashov/skills/blob/eacfc09b365d2697b83355909d0300607e596ffc/solidity-auditor/SKILL.md) assigns twelve specialists across arithmetic, access control, economics, execution, invariants, periphery, assumptions, asymmetry, boundaries, and numerical/trust/flow gaps. Its [economic agent](https://github.com/pashov/skills/blob/eacfc09b365d2697b83355909d0300607e596ffc/solidity-auditor/references/hacking-agents/economic-security-agent.md) covers dependency failures, unusual tokens, atomic extraction, ERC mismatches, and shared-capacity exhaustion. It demands concrete profit or loss figures.

Pashov prioritizes exploitable harm over style, gas, self-harm, or intended admin powers. Its judging rules distinguish material loss from non-compounding dust. The [report format](https://github.com/pashov/skills/blob/eacfc09b365d2697b83355909d0300607e596ffc/solidity-auditor/references/report-formatting.md) sorts by confidence, not severity; confidence is not an impact rating.

Trail of Bits' [token checklist](https://github.com/trailofbits/skills/blob/2be6433b39e009cd2b6fd3be1895f6b1faa5af9a/plugins/building-secure-contracts/skills/token-integration-analyzer/resources/ASSESSMENT_CATEGORIES.md) covers return-value quirks, hooks, balance changes, permissions, decimals, permit differences, and NFT behavior. Its [token report template](https://github.com/trailofbits/skills/blob/2be6433b39e009cd2b6fd3be1895f6b1faa5af9a/plugins/building-secure-contracts/skills/token-integration-analyzer/resources/REPORT_TEMPLATES.md) places unsafe transfers and loss-causing ERC failures first, then fee/rebase integration risks. Its separate [divergence rubric](https://github.com/trailofbits/skills/blob/2be6433b39e009cd2b6fd3be1895f6b1faa5af9a/plugins/spec-to-code-compliance/skills/spec-to-code-compliance/resources/DIVERGENCE_RUBRIC.md) ranks actual consequence and attacker reachability above textual mismatch.

## What a finding contains

Pashov's shared rules require contract/function location, bug class, root-cause grouping, caller-to-impact path, concrete proof, description, and suggested fix. "No proof = LEAD, no exceptions." Its final report prints location, confidence, description, and a fix above the confidence threshold; it does not require separate severity or proof sections. The judging file also permits some lead promotions without completed traces. Treat that internal tension as a reason to retain proof in task criteria.

Trail of Bits has distinct formats. Its token report requires pattern, presence, severity, file/line evidence, and mitigation. Its [requirement analysis](https://github.com/trailofbits/skills/blob/2be6433b39e009cd2b6fd3be1895f6b1faa5af9a/plugins/spec-to-code-compliance/skills/spec-to-code-compliance/resources/ANALYSIS_FORMAT.md) requires the quoted requirement, verdict/confidence, enforcement location, paths walked, searches, reasoning, and open questions. Its divergence rubric adds consequence: who acts, in what order, and what they obtain. These formats do not universally require executable proofs.

## What pattern matching misses

Inference from these methods: recognizing a check does not establish that every writer preserves its property. Recognizing a helper name does not establish its behavior on every branch. A familiar transfer pattern does not establish the token's accounting semantics.

Pashov explicitly targets stale reads, coupled state, and assumption chains. Trail of Bits warns that a requirement can hold on common paths and fail elsewhere. These support realistic repository audits with protocol context and meaningful state histories. They do not establish that current frontier models fail such tasks; trials must establish that.

## Principles worth building tasks around

- Inspect every writer: accounting or bounds violations through a secondary update path.
- Follow callees and callers: missing enforcement where two components each trust the other.
- Track state across transactions: stale snapshots or settlement rules broken by an intervening action.
- Model actual dependencies: token or oracle behavior that corrupts accounting or blocks withdrawals.
- Quantify cumulative effects: rounding or fee errors that become material through repeated operations.
- Compare guarantees across paths: a reachable branch that breaks a documented solvency or withdrawal promise.

## What these skills say models already do well

Pashov's SOP says, "Pattern-matching catches the obvious bugs". This is an author claim, not comparative model evidence. The reviewed Trail of Bits files provide no broad claim of measured vulnerability-detection strength.
