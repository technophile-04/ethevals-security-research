# Brief: round three, judge-graded root-cause questions

Read /tmp/subagents/security-quizzes/brief.md for the shared rules (no greeting, no eval words, under 130 words including code, write incrementally, incident backing with a URL). Then read /Users/shivbhonde/Desktop/github/ethevals/docs/adr/0016-quizzes-with-explained-answers-use-a-judge.md and one judged quiz, /Users/shivbhonde/Desktop/github/ethevals/tasks/concepts/agent-registries/ (instruction, tests/, hand-cases.json), so your output fits the runner.

## What the owner asked for

Hard questions graded by an LLM judge, each resting on something that really happened or was really disclosed: a post-mortem, a Trail of Bits or Osec or OpenZeppelin write-up, a Solidity security alert, a Code4rena or Sherlock finding. His words: "we don't want to frame them such that the model fails, but actually it has some exploit related to it or had some attack or hack or mentioned in Trail of Bits or something like that." The question is the auditor's real deliverable: what is the root cause, what should the reviewer flag, what does the reviewer conclude.

## Shape

Every instruction opens with the line "You are an expert security researcher and smart contract auditor." Then code modelled on the incident, 6 to 15 lines, with names, numbers and layout changed enough that remembering the incident alone does not give the answer; the reader has to read the code. Pin versions where behaviour depends on them. Then one question and the answer line "Answer in one sentence." Describe behaviour and loss; avoid the verbs attack, exploit, drain, steal and bypass where you can, since they trip an API content filter.

Each candidate needs, in the brief.md layout plus these fields:
- **Judge criterion:** one binary sentence the judge can check against a single reply, as in "passes if the reply says the postOp charge is collected after execution, so a reverting postOp leaves the paymaster paying; fails otherwise". A hedge between two causes fails. A reply naming a different real bug in the snippet fails.
- **Hand cases:** six one-line replies with pass or fail: two clear passes, one pass in different words, one hedge (fail), one near-miss naming a related but wrong cause (fail), one confident wrong answer (fail).
- **Verified by:** a Foundry test under /tmp/subagents/security-quizzes/pilot/<slug>/ when the question is about what code does, with the pinned compiler; or, when the question is about protocol design, the post-mortem line and the code at the pinned commit or tag that fixes the answer.

## Where to look

The owner wants these to come from what audit firms and contest platforms actually found. Start from published findings: Trail of Bits' public reports (github.com/trailofbits/publications, reviews folder) and blog, Spearbit's portfolio reports (github.com/spearbit/portfolio), Quantstamp certificates, Cantina and Sherlock and Code4rena contest findings (High and Medium), OpenZeppelin audit reports, Osec and Dedaub write-ups. Pick findings whose root cause fits in 6 to 15 lines of code and whose fix is in the public repo. Prefer 2024 to 2026: Penpie (Sep 2024), Sonne (May 2024), Resupply (Jun 2025), GMX v1 (Jul 2025), Balancer v2 stable pools (Nov 2025), Bunni (Sep 2025), Cork (May 2025), Moonwell (Nov 2025), zkLend (Feb 2025), IPOR (Jan 2026), the Osec paymaster series (Dec 2025), Trail of Bits "Six mistakes in ERC-4337 smart accounts" (Mar 2026), Solidity security alerts 2025 to 2026, OpenZeppelin advisories, EIP-7702 delegation drainers (2025). Older is fine when the pattern still ships today. Skip Bybit (famous and filtered), the DAO, Parity, Wormhole, classic reentrancy and tx.origin.

Do not reuse any topic in /tmp/subagents/security-quizzes/asked-slugs.txt or in /tmp/subagents/security-quizzes/pilot-opus.md.

Write 6 candidates to /tmp/subagents/security-quizzes/pilot-judge.md. Six good ones beat twelve thin ones. For each, name the firm or platform, the report or finding, its severity, and the URL. Your last message: how many candidates, how many proved by a test versus by a cited line, and the three you think are strongest.
