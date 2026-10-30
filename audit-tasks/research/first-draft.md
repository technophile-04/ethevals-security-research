# Lead's draft view (read only after you have written your own answer)

## How a security task differs from a dapp-dev task

- dapp-dev: the instruction is a builder's message. The miss lives in what the builder never said; the hidden checks look at what a senior developer does unprompted.
- security: the instruction says exactly what is wanted: audit this code and report the vulnerabilities. Nothing is hidden in the ask. The miss lives in the code: a vulnerability that takes real audit work to find. The check is plain: did the report name it, with where it is, its root cause and what it breaks.
- So the dapp-dev filter "would a competent developer still get it wrong?" becomes "would a quick pattern-matching pass miss it, where a careful auditor who maps the protocol finds it?"
- The client's docs matter more than in dapp-dev: many real Highs are "the code does not do what the protocol says it does". A contest hands auditors a README with the intent and the trust model (who is trusted). Our task should too.

## Task shape

- Role line (already settled): "You are an expert security researcher and smart contract auditor."
- Environment: a Foundry project with a real protocol, not an excerpt: one to a handful of contracts, a few hundred to ~2,000 lines, its tests, and a README with intent, scope and trust model.
- Instruction: a client's audit request. Scope, what to write (findings.md, one finding per issue: location, root cause, impact, severity). Short, readable cold.
- Checks: one judge question per known vulnerability (1-3 per task, High or Medium): "Does a finding name <root cause> in <function> and say it lets <impact>?" Score is the share found; the task passes when every High is found.
- Ground truth: real findings from audit contests or firm reports (Code4rena, Sherlock, Cantina, Pashov audits), at the audited commit. Evidence comes by construction, and nothing is a trick: real auditors found these in real code.
- Optional second check on a few tasks: a Foundry proof-of-concept that the verifier runs against the original code (EVMbench's exploit mode). Raises the bar; not the main measure.
- False findings: not a check in the first batch. At most one or two later tasks, using the contest's own "known issues" list.

## Why this, given the measurements

- Ten-line excerpts and 12 small multi-issue contracts: every frontier model found every issue. Size and the need to understand the protocol are what was missing, and real codebases supply both.
- GLM missed whole Highs on five small contracts; at real size open models should miss more (guess, untested).

## How to find one (security version of the meta doc's steps)

1. Pick a block from the map (lending, vaults, DEX, staking, bridges, governance, account abstraction).
2. Find two or three recent audit reports for that block with a High whose root cause needs the auditor's method (accounting across functions, an invariant the docs state and the code breaks, a trust boundary), not a famous-pattern lookup.
3. Take the audited code at that commit and the contest's README. Trim only what the finding does not touch, and keep it real.
4. Trial cheaply with a strong and an open agent; read their findings; keep the task when an open model misses a High and a frontier model misses in some trial or finds it only after real reading.

## Open risks

- Contamination: public findings may be in training data. Prefer recent contests; measure it.
- Content filters: Opus filtered some security review in bare screens; the agent harness may differ. Count refusals as failures, flag them.
- Pillar: an audit report is not a quiz, a build or an act as CONTEXT.md defines them. Needs a vocabulary call.
- Cost: agentic trials on real codebases cost more than quiz screens.
