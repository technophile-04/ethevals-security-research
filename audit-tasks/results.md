# Audit-task trial results

One row per scored trial. `found` lists the known vulnerabilities the judge credited.

| Round | Task | Agent | Trial | Result | Found | Agent time | Model cost (est.) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| round 1 | audit-governance | Claude Code (Opus 5.5) | 1 | passed | 2 of 2 | 149 s | $0.62 |
| round 1 | audit-staking | Claude Code (Opus 5.5) | 1 | passed | 2 of 2 | 144 s | $0.55 |
| round 1 | audit-dex | Claude Code (Opus 5.5) | 1 | passed | 1 of 1 | 211 s | $0.76 |
| round 1 | audit-vault | Claude Code (Opus 5.5) | 1 | passed | 2 of 2 | 164 s | $0.64 |
| round 1 | audit-governance | Codex (GPT-6.1-sol) | 1 | passed | 2 of 2 | 296 s | $0.19 |
| round 1 | audit-staking | Codex (GPT-6.1-sol) | 1 | passed | 2 of 2 | 441 s | $0.20 |
| round 1 | audit-dex | Codex (GPT-6.1-sol) | 1 | passed | 1 of 1 | 433 s | $0.21 |
| round 1 | audit-vault | Codex (GPT-6.1-sol) | 1 | passed | 2 of 2 | 292 s | $0.18 |
| round 1 | audit-dex | Kimi K3.1 (OpenCode) | 1 | passed | 1 of 1 | 662 s | $0.39 |
| round 1 | audit-dex | DeepSeek V4.1 Flash (OpenCode) | 1 | passed | 1 of 1 | 631 s | $0.14 |
| round 1 | audit-governance | Kimi K3.1 (OpenCode) | 1 | passed | 2 of 2 | 1586 s | $0.38 |
| round 1 | audit-governance | DeepSeek V4.1 Flash (OpenCode) | 1 | passed | 2 of 2 | 192 s | $0.04 |
| round 1 | audit-staking | Kimi K3.1 (OpenCode) | 1 | passed | 2 of 2 | 955 s | $0.19 |
| round 1 | audit-staking | DeepSeek V4.1 Flash (OpenCode) | 1 | passed | 2 of 2 | 535 s | $0.08 |
| round 1 | audit-vault | Kimi K3.1 (OpenCode) | 1 | error: provider API rejected a request | 0 of 2 | 1161 s | $0.20 |
| round 1 | audit-vault | DeepSeek V4.1 Flash (OpenCode) | 1 | passed | 2 of 2 | 437 s | $0.08 |
| vault grown | audit-vault | Claude Code (Opus 5.5) | 1 | passed | 2 of 2 | 378 s | $1.21 |
| vault grown | audit-vault | DeepSeek V4.1 Flash (OpenCode) | 1 | passed | 2 of 2 | 710 s | $0.15 |
| round 2 | audit-dex | Claude Code (Opus 5.5) | 1 | passed | 3 of 3 | 303 s | $1.21 |
| round 2 | audit-vault | Claude Code (Opus 5.5) | 1 | passed | 2 of 2 | 373 s | $1.43 |
| round 2 | audit-vault | DeepSeek V4.1 Flash (OpenCode) | 1 | passed | 2 of 2 | 712 s | $0.12 |
| round 2 | audit-vault | DeepSeek V4.1 Flash (OpenCode) | 2 | passed | 2 of 2 | 679 s | $0.17 |
| round 2 | audit-dex | Kimi K3.1 (OpenCode) | 1 | missed `launch_clock_starts_at_creation` | 2 of 3 | 1254 s | $0.38 |
| round 2 | audit-dex | Kimi K3.1 (OpenCode) | 2 | passed | 3 of 3 | 1504 s | $0.38 |
| round 2 | audit-dex | DeepSeek V4.1 Flash (OpenCode) | 1 | passed | 3 of 3 | 518 s | $0.11 |
| round 2 | audit-dex | DeepSeek V4.1 Flash (OpenCode) | 2 | passed | 3 of 3 | 792 s | $0.27 |
