# Context for every helper on this job

ETH Evals (repo: /Users/shivbhonde/Desktop/github/ethevals) is a benchmark of AI agents on Ethereum work. It has a dapp-development domain and is opening a second domain: smart-contract security. Read docs/dapp-dev-meta-doc.md in the repo once for how the team thinks about tasks; the security domain is different, see below.

## What the team wants from security tasks

Put the model in the role of a smart-contract security auditor, give it an audit job the way a client would, and check whether it finds the real vulnerabilities. The main thing measured is: did it catch the vulnerabilities that matter. One or two tasks may also check for false findings, but that is a side check, not the goal.

## What went wrong in the last attempt (do not repeat)

Another session ran five rounds of cold quizzes (Oct 29-30). Lessons:
- It drifted into puzzle-style questions: snippets shaped like a famous bug that isn't, decoys with a textbook smell next to the real cause, "the owner finds the NFT gone, what is the root cause?". Shiv rejected this. An audit task should not trick the model.
- It drifted into measuring false findings (precision) as a main axis. Shiv rejected this as the main goal.
- It went too deep into research (six researchers, 84 candidates, fact-checkers).
- Measured results: isolated ten-line findings were found by every current frontier model (Opus 5.5, GPT-6.1-sol) in every call. Twelve small multi-issue contracts with 2-3 real issues each: Opus and GPT named every issue; GLM missed whole High-severity issues on five contracts; Kimi on one. The cold quiz form is saturated for frontier models.
- Existing benchmark framing already noted: EVMbench (OpenAI + Paradigm, github.com/openai/frontier-evals, project/evmbench) opens with "You are an expert security researcher and smart contract auditor." and asks for a vulnerability report; refusals count as failures.

## Rules for you

- Stay light. One clear question, a short report, stop when you can answer it. No more than about 20 sources or 40 tool calls.
- Quote and link primary sources (repo files, papers, official docs). Mark anything you infer as inferred.
- Do not write exploit code, proofs or task drafts. Research only.
- Write your report to the file your task names. Keep it under 900 words.
