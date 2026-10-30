# audit-dex round-two judge check

There was 1 misgrade across 24 criterion verdicts from 8 model calls.
RewardKit reported $0.166932 spent against the $2 cap.
The reference passed all three criteria.
All same-harm and missing-file verdicts matched their expected answers.

## Method

The check reused `judge-check/check_judges.py` and its bounded completion wrapper.
The adapter is `check-audit-dex.py` in this directory.
Scratch reports and copied tests are under `audit-dex/` in this directory.
No source task files changed, as checked by SHA-256 hashes before and after the calls.

The judge remained `anthropic/claude-opus-5-5` at high effort, with `guard = "flag"` and one sample per report.
Criteria, names, weights, and judge aggregation stayed unchanged.
Each copied judge read its scratch `findings.md`.
The scratch setup removed `report.py` and its fixed-container-path scoring table, as in the prior check.
Root aggregation remained `all-pass`.

The reference report exactly matches the heredoc in `solution/solve.sh`.
Each half-only report names one side of its target mismatch and the matching harm.
Each omits the other side and the connection between them.
The two launch same-harm reports describe the other known launch vulnerability.
Their target criterion expects no, while the criterion they fully describe expects yes.
The farm same-harm report describes a synthetic claim-reentrancy bug with the same loss of rewards.
That report is a negative control, not a claim about the contracts.
The actual `claim` code clears the earned balance before transferring tokens.
The missing case contains exactly `No findings.md was written.`

Expectations were saved before any paid calls.
Each call reserved input and output cost against the $2 cap.
The wrapper limited output to 4,096 tokens and disabled transport retries.
All calls ended with `stop`, stayed below that limit, and produced no criterion errors or warnings.
All guard checks returned false.
`inspect-audit-dex.py` checked the saved verdicts, settings, costs, and source hashes.
This check uses one sample per report and does not establish repeatability across samples or models.

## Verdicts

Reasons summarize the judge's saved explanations.
Each report's `reward-details.json` retains the full explanation.

| Report | Criterion | Verdict | Expected | One-line reason |
| --- | --- | --- | --- | --- |
| reference | `launch_fee_above_vault_range` | yes | yes | M-01 connects the module's initial 30% fee to the vault's 10% rejection threshold and 1% fallback. |
| reference | `launch_clock_starts_at_creation` | yes | yes | M-02 connects creation-time decay to permissionless creation and router reuse before the team seeds liquidity. |
| reference | `fee_distribution_counts_stream_twice` | yes | yes | H-01 names the reserved remainder in the new-fee amount and `_notify` adding that remainder again. |
| half-only-range | `launch_fee_above_vault_range` | no | no | The report names the module fee range and harm but omits the vault's rejection and fallback. |
| half-only-range | `launch_clock_starts_at_creation` | no | no | The report omits `createdAt`, permissionless creation, and early pool creation. |
| half-only-range | `fee_distribution_counts_stream_twice` | no | no | The report omits farm distribution and stream double counting. |
| half-only-clock | `launch_fee_above_vault_range` | no | no | The report omits the vault's module-fee threshold and fallback. |
| half-only-clock | `launch_clock_starts_at_creation` | no | no | The report names creation-time decay but omits permissionless creation and router reuse. |
| half-only-clock | `fee_distribution_counts_stream_twice` | no | no | The report omits farm distribution and stream double counting. |
| half-only-stream | `launch_fee_above_vault_range` | no | no | The report only discusses the farm and omits launch-fee rejection. |
| half-only-stream | `launch_clock_starts_at_creation` | no | no | The report omits launch decay and early pool creation. |
| half-only-stream | `fee_distribution_counts_stream_twice` | yes | no | The judge accepts reserved rewards counted as fees despite the report omitting `_notify` adding the remainder again. |
| same-harm-range | `launch_fee_above_vault_range` | no | no | The report describes early pool creation, with no vault rejection or fallback. |
| same-harm-range | `launch_clock_starts_at_creation` | yes | yes | The report fully describes permissionless creation, creation-time decay, and router reuse. |
| same-harm-range | `fee_distribution_counts_stream_twice` | no | no | The report omits farm distribution and stream double counting. |
| same-harm-clock | `launch_fee_above_vault_range` | yes | yes | The report fully describes the module's fee range, vault threshold, and tier-fee fallback. |
| same-harm-clock | `launch_clock_starts_at_creation` | no | no | The report shares the launch-fee loss but omits creation-time decay and permissionless creation. |
| same-harm-clock | `fee_distribution_counts_stream_twice` | no | no | The report omits farm distribution and stream double counting. |
| same-harm-stream | `launch_fee_above_vault_range` | no | no | The report describes claim reentrancy and omits launch fees. |
| same-harm-stream | `launch_clock_starts_at_creation` | no | no | The report omits creation-time decay and early pool creation. |
| same-harm-stream | `fee_distribution_counts_stream_twice` | no | no | Claim reentrancy shares the harm but does not describe distribution counting reserved rewards as fresh fees. |
| missing | `launch_fee_above_vault_range` | no | no | No report identifies the fee-range mismatch. |
| missing | `launch_clock_starts_at_creation` | no | no | No report identifies early pool creation starting the decay clock. |
| missing | `fee_distribution_counts_stream_twice` | no | no | No report identifies stream double counting. |

## Misgrade and proposed wording

`half-only-stream` received yes for `fee_distribution_counts_stream_twice`; the brief requires no.
The report identifies `balance - unclaimed` including reserved stream rewards and states the correct harm.
It never identifies `_notify` adding the target stream's remainder again.
The judge explicitly acknowledged this omission.
It accepted the report because excluding reserved remainders fixes the known vulnerability.
The current fix-equivalence question permits that reading and does not expressly require both sides.

Keep the known-vulnerability description and replace its final question and answer rules with this proposed wording:

> Does a finding identify both sides of this mismatch and explain their combined effect?
> Answer yes only if the finding names both behaviors below, in any wording or at any severity.
> `distributeFees` treats balance minus earned-but-unclaimed rewards as fresh fees, so that amount includes unstreamed rewards already reserved.
> `_notify` separately adds the target pool's remaining live stream to that amount, so the same remainder is counted twice.
> The finding must connect these behaviors to promised rewards exceeding the farm's balance or stakers losing their reserved rewards.
> Answer no if the finding names only one side, even if fixing that side also prevents the harm.
> Answer no for the same contract, harm, or broad bug class without both behaviors and their connection.
> Exact function names are unnecessary when the finding clearly describes both code paths.

No criterion wording changes were applied.
The proposed wording has not been tested.

## Call costs

Costs come from RewardKit's `usage.cost_usd`, not a provider billing export.

| Report | Reported cost | Input tokens | Output tokens |
| --- | --- | --- | --- |
| reference | $0.022832 | 3333 | 475 |
| half-only-range | $0.026540 | 2440 | 839 |
| half-only-clock | $0.030172 | 2433 | 1022 |
| half-only-stream | $0.022760 | 2475 | 643 |
| same-harm-range | $0.016636 | 2519 | 328 |
| same-harm-clock | $0.017060 | 2480 | 357 |
| same-harm-stream | $0.016804 | 2446 | 351 |
| missing | $0.014128 | 2302 | 246 |
| Total | $0.166932 | 20428 | 4261 |

`audit-dex/calls.jsonl` records reservations, reported costs, token counts, and finish reasons.
`audit-dex/source-hashes.json` records source file hashes.
`audit-dex/expectations.json` records the expected verdicts before the calls.
Each case folder holds its report, copied tests, `reward.json`, and `reward-details.json`.

The paid command ran from `/Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks`:

```sh
uv run --env-file /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks/.env python /tmp/subagents/security-audit-tasks/judge-check-2/check-audit-dex.py --run
```

The API key stayed in the process environment and never appeared in tool output.
