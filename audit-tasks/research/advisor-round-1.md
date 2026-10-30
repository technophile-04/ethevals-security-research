# Fable advice: framing the security audit tasks

## 1. How a security task differs from a dapp-dev task

In dapp-dev the ask is a builder's message and the miss lives in what the builder never said. In security the ask is complete: audit this code, report what you find. The miss lives in the code and in the gap between what the README promises and what the code does. The difficulty is coverage: map the protocol, follow state across functions and transactions, check every writer of what the README guarantees.

Dapp-dev checks run the agent's code or read the chain. A security check reads a report and asks, per known vulnerability: does a finding name this mechanism on this code path, so that fixing what the report says would fix the real bug. That is EVMbench's test and it is the right one.

What carries over: evidence behind every task, trial before checks, the open-model-must-miss bar, short instructions, judge questions that name the code they rest on, a README that explains the miss.

What must not carry over: the "what did it do unprompted" axis, the builder story, the merge-block filter. The filter is: would the client lose funds, and does finding it take audit work rather than recognition. Do not import the quiz habit of shaping code so it looks like something. Real code, real README, no decoys.

## 2. The shape

Environment: a Foundry project at the audited commit, building, tests passing. One to a handful of contracts, roughly 300 to 1,500 lines in scope. A README with what the protocol does, who is trusted, what is in scope and the known issues, written as a client would. No internet. The runner is not ready for this: every agent mode has the web, and with the web an agent fetches the contest report. An offline agent mode comes before the first paid trial.

Instruction: the settled role line, then a client's request under 100 words: what the protocol is, where the README is, what to write (a findings file, one finding per issue with location, root cause, impact, severity, the path from caller to harm). No count, no hint at the kind.

Checks: one judge criterion per known High, and per Medium where one is clean, two to four per task. Each criterion holds the private description: function, mechanism, harm. The judge answers EVMbench's key question; same contract or same impact is not enough. Score is the share found. The task passes when every High is found. Severity is asked for, not scored.

Ground truth: the public finding, plus a Foundry test on our side that proves it on that commit. The proof is the solution. It never reaches the agent, and the agent is never asked to write one.

## 3. Where vulnerabilities come from

Real findings at the audited commit, first batch only. They are evidence by construction, they cannot be a trick, and Shiv can read the public finding and judge it fair. Planted bugs lose all three; they are the quiz drift in another coat.

Contamination is the cost. Measure it before keeping a task: ask a bare model, with the project and file names, what the audit found. If it recites, strip the names and ask again. If it still recites, drop the task. Prefer contests from the last six to nine months for this reason alone. That differs from the newness Shiv rejected: offline, recency hides nothing from the agent, it only keeps the finding out of training.

Readability is a gate. Pick findings whose story Shiv follows in ten minutes: the README says X, this function breaks X, this party loses money.

## 4. Next to EVMbench

EVMbench does detect, patch and exploit on 40 Code4rena audits, offline, GPT-5 judged. A smaller copy adds nothing. ETH Evals can add:

- Open agents as subjects: GLM and Kimi inside real agents, trajectories on a public board. EVMbench reports frontier recall as a number.
- The skills mode: the same audit with and without the Pashov and Trail of Bits skills installed. Nobody publishes that, and auditors are asking.
- Readable tasks: ten to fifteen, each README saying what the finding is and who missed it.
- Current code: 2026 contests on current Solidity, next to dapp-dev tasks in the same areas, so the board shows building and auditing together.

No patch or exploit modes, no forty tasks, no recall leaderboard.

## 5. The false-finding check

Not scored in the first batch. Round five showed precision flipping with the judge on 36 of 137 rows. Record claims the judge marks as contradicting the code as an unscored column. If one task later checks it, use the README's known-issues list: resubmitting a known issue means the brief was not read. One task at most.

## 6. Pillar

An audit report is not a quiz, a build or an act. Pillar is "the kind of work a task asks for" and auditing is a fourth kind. Add Audit by ADR, with the security domain holding Concepts and Audit. If that cannot land before the ship date, run the first batch as Build, note that the tests read what the agent wrote, and record the debt. Do not bend Concepts to fit it.

## 7. How this goes wrong

The quiz rounds failed by bending the form until a frontier model missed: decoys, puzzles, compiler trivia. The same pull here is to trim the repo down to the finding, which recreates the ten-line excerpt every model finds, or to pick the most obscure finding to force a miss. Hold the line: take the contest scope as it is, pick small contests over trimmed big ones, and let the first trials show the gap. If frontier agents find every High at 1,000 lines offline, publish that; the open-model misses still make the tasks worth having.

Smaller ways: a pass that is recitation because contamination went unmeasured, and a judge that credits "accounting may be off" without the code path.

## On the lead's draft

Agree with most of it: role line, real-repo environment, real findings at the audited commit, judge per known vulnerability, pass on every High, no false-finding check in batch one, the risks, the four finding steps.

Where I differ:

- Internet. The draft never says the agent is offline. All our modes have the web. This blocks the first trial and needs runner work first.
- "Trim only what the finding does not touch." Do not trim. Trimming brings back the excerpt and the trick. Pick small scopes.
- The optional Foundry proof check. Drop it from batch one. The proof is our solution, not the agent's deliverable.
- "Would a quick pattern-matching pass miss it." Fine as taste, a guess until trialled, and read carelessly it leads back to decoys. The measured filter is the open-model miss and a frontier trajectory that shows reading and testing.
- Contamination. "Prefer recent, measure it" needs the how: recitation probe with and without names, drop on recite.
- Pillar. Make the call: Audit, by ADR.
- Missing: the skills mode, and the readability gate per finding.
- Severity: ask for it, do not score it.
