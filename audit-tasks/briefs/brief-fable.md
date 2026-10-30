# Fable advisor: does this framing for security tasks make sense?

You advise Shiv, who runs ETH Evals (repo: /Users/shivbhonde/Desktop/github/ethevals), a benchmark of AI agents on Ethereum work. He is opening a second domain, smart-contract security, next to dapp development. You are the advisor on task framing. Research and judge only; write no code, no exploit, no task drafts.

## Read first

1. /tmp/subagents/security-audit-tasks/context.md: what the team wants and what went wrong last time.
2. docs/dapp-dev-meta-doc.md in the repo: how dapp-dev tasks are found and shaped.
3. CONTEXT.md in the repo, the entries "Pillar", "Quiz", "Judge" and "Builder story".
4. These memory notes (background, written by earlier sessions): /Users/shivbhonde/.claude/projects/-Users-shivbhonde-Desktop-github-ethevals/memory/security-domain-quizzes.md, /Users/shivbhonde/.claude/projects/-Users-shivbhonde-Desktop-github-ethevals/memory/security-domain-carlos-10-15.md, /Users/shivbhonde/.claude/projects/-Users-shivbhonde-Desktop-github-ethevals/memory/security-benchmark-framing.md, /Users/shivbhonde/.claude/projects/-Users-shivbhonde-Desktop-github-ethevals/memory/tasks-need-evidence-and-a-miss.md, /Users/shivbhonde/.claude/projects/-Users-shivbhonde-Desktop-github-ethevals/memory/trial-before-checks.md, /Users/shivbhonde/.claude/projects/-Users-shivbhonde-Desktop-github-ethevals/memory/no-instruction-tweaks-for-refusals.md, /Users/shivbhonde/.claude/projects/-Users-shivbhonde-Desktop-github-ethevals/memory/instructions-short-for-humans.md.
5. The two research reports: /tmp/subagents/security-audit-tasks/research-benchmarks.md and /tmp/subagents/security-audit-tasks/research-skills.md. Open the linked EVMbench DETECT.md and judge file if you want the exact text.

## Shiv's words today (verbatim, voice-typed)

"we want to come up with smart-contract security. Now mind that there are some difference b/w smart-contract-security type of tasks and dapp-dev type of task. so be careful going towards wrong trajectory."

"for some reason the model started with puzzle-type questions, which doesn't make sense because we are doing a security audit task. we don't want to trick it. it would be like how a normal user gives the question, not like a normal user but like putting a model into the role of a security auditor: giving it the task and checking whether it's able to find the vulnerabilities or not."

"instead of it stressing on finding the actual vulnerability, it started thinking about whether i could check whether this model gives false findings, which doesn't make sense. there could be one or two tasks or checks where we check for false findings but that shouldn't be our main goal at all. our main goal was to see whether the models are able to catch the security vulnerabilities really nicely."

"if you look at ctf or other repos, that is how it's framed but i want you to take the core principles of it or core patterns of it. maybe we can see them in the skills of [Cantina] or in the skill of [Pashov]. we need to take the important principles from those skills"

## Questions

Answer these yourself first, before reading the lead's draft:

1. What is the real difference between a security task and a dapp-dev task, in how the instruction is written, where the difficulty lives, and what a check looks at? What from the meta doc carries over and what must not?
2. What shape should a security task take (environment, instruction, checks, ground truth)? Be concrete enough that someone could build one.
3. Where should the vulnerabilities come from: real contest or audit findings at the audited commit, bugs we plant into real code, or something else? Weigh contamination (public findings in training data), evidence, readability for Shiv, and the "no tricks" rule.
4. EVMbench already exists and does detect, patch and exploit on 40 Code4rena audits. What should ETH Evals do so its security tasks are worth having next to it, not a smaller copy?
5. Where does the small false-finding check belong, if anywhere, in a first batch?
6. Which pillar would such a task sit in, given CONTEXT.md's definitions? Say whether a vocabulary change is needed.
7. The biggest way this plan could go wrong, the way the quiz rounds did.

Then read /tmp/subagents/security-audit-tasks/lead-draft.md and say plainly where you agree, where you differ, and what you would change. Do not soften.

Write your answer to /tmp/subagents/security-audit-tasks/fable-advice.md, under 1,200 words, plain sentences. Your last message is a five-line summary.
