# Brief: candidate security quizzes for ETH Evals

You are drafting candidate quiz questions for a new "security" domain of ETH Evals, a public benchmark that tests AI agents and bare models on real Ethereum work. Repo: /Users/shivbhonde/Desktop/github/ethevals. Read before drafting:
- docs/dapp-dev-meta-doc.md (what a task is for, the bar, the two kinds)
- tasks/concepts/permit2-7702-signature/ (instruction.md and README.md, a quiz that survived)
- tasks/concepts/smart-accounts-userop-hash-v08/instruction.md and tasks/concepts/governance-arbitrum-block-clock/instruction.md (two more survivors, for form)

## What a quiz is

A short question with a fixed answer that stays the same whichever library you use. The model answers in one reply, no tools, no web. The last sentence of the instruction fixes the answer form, using exactly one of:
- "Answer yes or no, then explain in one sentence."
- "Answer X or Y, then explain in one sentence." (X and Y are the two candidate answers)
- "Answer with the <number/name> only."
- "Answer in one sentence." (only when no fixed form is possible; a judge then grades the sentence against one binary criterion)

Open with the ask itself. No greeting. Never use the words eval, benchmark, score, test or quiz in the instruction. Plain English, under 120 words. A Solidity or TypeScript code block inside the instruction is welcome when the question is about that code. Name Ethereum concepts with the words ethereum.org and the EIPs use.

## The bar (this is what makes drafting hard)

A quiz is kept only if, when asked cold, a bare open model (GLM or Kimi) answers wrong AND at least one bare frontier model (Claude Opus 5.5 or GPT-6.1) answers wrong. Security is the best-documented corner of Ethereum. Textbook questions (reentrancy, tx.origin, unchecked return values, integer overflow, the SWC list, "what is a flash loan attack") are answered perfectly by every model. Do not draft those. The owner's words: "textbook security questions are exactly what bare models answer well."

What survives: a question whose correct answer depends on a specific, verifiable fact that models commonly hold a stale or over-general belief about. Examples of the pattern (do not copy these, they already exist or are dapp-dev quizzes):
- Permit2 verifies a signature from an EIP-7702-delegated EOA via ERC-1271, not ecrecover, because the account now has code. Models assume "EOA key signed it, so ecrecover".
- Arbitrum's block.number is the L1 block number, so an OpenZeppelin Governor clock in blocks runs at L1 pace. Models assume block.number is the chain's own block.

Each candidate must also pass a pragmatic filter: it must be a question a senior auditor would actually ask about real code or a real deployment, phrased as an auditor hunting bugs (e.g. "You are reviewing this vault before launch", "This contract holds $40M on mainnet"). Not a CTF puzzle, not EVM trivia (address nibble grinding, RLP headers, exact gas windows), not "what year was X hacked" news trivia. The incident is the backing, not the question.

Each candidate must have real backing: a named hack, incident, disclosed bug, or post-mortem where this exact concept cost money or nearly did. Prefer 2024 to 2026 incidents, since those are the ones a senior auditor is thinking about today, but older is fine if the concept still applies unchanged. Verify every incident and every spec fact against a primary source with web search (EIPs at eips.ethereum.org, the protocol's own post-mortem, rekt.news, the audit report, the Solidity docs, the chain's own docs). Record the URL. If you cannot verify a fact, say so in the candidate rather than asserting it.

## Your output

Write to the file named in your task. Produce 12 to 16 candidates. For each, use exactly this layout:

### <short slug, kebab-case, starting with the topic word>
**Instruction:**
<the full instruction text as the model will see it, code block included if any>

**Answer:** <the fixed answer, then one sentence of the reasoning>

**Why a model gets it wrong:** <the specific stale or over-general belief, one or two sentences. Be honest: if you think a 2026 frontier model probably knows this, say "likely known" here and still include it, so the owner can decide.>

**Backing:** <incident or disclosure, date, amount if any, URL of a primary source>

**Spec source:** <URL of the EIP, docs page, or code line that fixes the answer>

**Grading:** <"pattern: starts with X" or "judge: criterion ..." in one line>

**Your confidence a frontier model fails cold:** <high / medium / low>

End the file with a short section "Rejected on the way", listing ideas you dropped and why, one line each, so the consolidator does not re-draft them.

## Hard rules
- Do not edit anything in the repo. Write only to your output file.
- Do not read agent trajectories or reasoning text anywhere.
- Each candidate must be answerable from the concept, not from having read the news. A good self-check: could a senior auditor who never heard of the incident still get it right by reasoning from the spec? If yes, keep. If the only path to the answer is remembering the incident, drop it.
- Do not drift into build tasks. These are questions only.
