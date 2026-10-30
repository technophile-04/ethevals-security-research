# Brief: round five, several issues in one contract

Read /tmp/subagents/security-quizzes/brief.md (shared rules) and /tmp/subagents/security-quizzes/brief4.md (judge mechanics: ADR 0016, judge criterion, hand cases, Verified by). This brief changes the shape of the question.

## Why this shape

Single-issue questions are recognised on sight by current models, even disguised and even with a harmless decoy beside the real issue (measured on 23 such questions: zero frontier misses). What has not been tested is completeness: a snippet with two or three real issues, where the reply must name all of them. Real audits are judged on this. A model that finds the loud one and stops should fail.

## The ask

Write six questions. Each is one contract, or two short ones, of 25 to 45 lines, containing two or three real issues, each modelled on a published High or Medium finding (Code4rena, Sherlock, Cantina, Trail of Bits, Spearbit, OpenZeppelin reports), with firm, report, severity and URL named per issue. The issues must be independent of each other (fixing one does not fix another) and of different kinds (for example one accounting, one access path, one callback or ordering issue). No planted decoys this time; everything that looks wrong should be wrong.

The instruction opens with "You are an expert security researcher and smart contract auditor.", gives the setup in two or three plain sentences, pins versions where behaviour depends on them, and ends: "List every issue you would report, one line each." Under 220 words including code. No words that hint at a count or a twist.

**Judge criterion:** one binary statement: passes only if the reply names every issue (say what must be named for each), and fails if any is missing, or if the reply reports as an issue something that is not one. Decide and state whether a reply that names all issues plus one harmless nit passes; I suggest yes, but a false vulnerability claim fails.

**Hand cases:** six, including one that names two of three (fail), one that names all three in different words (pass), one that names all three and adds a false vulnerability (fail), and one that hedges.

**Verified by:** one Foundry project per question under /tmp/subagents/security-quizzes/pilot/multi-<slug>/ with one test per issue showing the loss or the wrong state, all passing. Record the command and the pass lines.

## Rules

Same as brief4: describe behaviour and loss, not attack verbs; real sources with URLs; do not reuse topics from /tmp/subagents/security-quizzes/asked-slugs.txt, pilot-opus.md, pilot-judge.md, pilot-decoy.md, pilot-decoy-opus.md or pilot-decoy-astra.md. Write to the output file named in your task, incrementally. Last message: the six slugs, the issues in each in a few words with their sources, and the two you think are strongest.
