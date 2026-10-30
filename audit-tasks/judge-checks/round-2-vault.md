# Audit-vault round-two judge check

The judge made 2 misgrades across 12 criterion verdicts from 6 model calls.
Both half-only reports received a false positive on their target criterion.
The reference, same-harm, and missing reports matched every expected verdict.
RewardKit reported $0.096872 in API cost against the $2 cap.

## Verdicts

Reasons below summarize the judge's saved reasoning.
Each report ran against both criteria, including the criterion it did not target.

| Report | Criterion | Verdict | Expected | One-line reason |
| --- | --- | --- | --- | --- |
| reference | `unbooked_loss_escapes_on_withdrawal` | yes | yes | H-1 connects booked valuation, live undeployment, and the loss left to remaining holders. |
| reference | `sold_rewards_skip_fee_and_unlock` | yes | yes | H-2 connects idle reward proceeds with immediate valuation and bypassed harvest fees and locking. |
| half-only-loss | `unbooked_loss_escapes_on_withdrawal` | yes | no | The judge accepts stale booked valuation plus harm despite the missing live withdrawal and undeploy accounting. |
| half-only-loss | `sold_rewards_skip_fee_and_unlock` | no | no | The finding does not discuss reward sales, fees, or profit locking. |
| half-only-rewards | `unbooked_loss_escapes_on_withdrawal` | no | no | The finding does not discuss strategy losses, booked valuation, or live withdrawals. |
| half-only-rewards | `sold_rewards_skip_fee_and_unlock` | yes | no | The judge infers the missing profit-lock bypass from the stated one-block capture of reward income. |
| same-harm-loss | `unbooked_loss_escapes_on_withdrawal` | no | no | Rounding down the shares burned is a different mechanism despite the same loss to remaining holders. |
| same-harm-loss | `sold_rewards_skip_fee_and_unlock` | no | no | The finding does not discuss reward sales or harvest fees and locking. |
| same-harm-rewards | `unbooked_loss_escapes_on_withdrawal` | no | no | Direct donations do not describe stale strategy valuation or losses left after withdrawals. |
| same-harm-rewards | `sold_rewards_skip_fee_and_unlock` | no | no | A donation entry point does not route strategy reward sales through harvest. |
| missing | `unbooked_loss_escapes_on_withdrawal` | no | no | No report exists to describe unbooked losses escaping through withdrawals. |
| missing | `sold_rewards_skip_fee_and_unlock` | no | no | No report exists to describe reward sales bypassing fees and locking. |

## Misgrades and proposed criterion wording

These proposals require both code halves, as the brief specifies.
The current repair question also permits a broader reading: fixing one identified half can resolve the whole bug.
The judge used that reading for the loss finding and inferred missing detail for the rewards finding.
The proposals remove the repair question and require the report to explain both halves.
No proposal was applied or tested.

### 1. `unbooked_loss_escapes_on_withdrawal`

`half-only-loss` received yes instead of no.
It names `totalAssets` using booked `deployedAssets` and the harm to remaining holders.
It omits withdrawals pulling live assets and `undeploy` reducing the booked amount only by the assets returned.
The judge acknowledged that omission but accepted a repair to booked-value pricing as sufficient.

Proposed replacement description:

> The file holds an audit report on the Sluice contracts.
> The known vulnerability combines stale share valuation with live withdrawals after a market loss.
> SluiceVault.totalAssets values strategies at deployedAssets booked by the last harvest, so unbooked bad debt leaves shares overpriced.
> Withdrawals pull live market assets through _ensureIdle and BaseStrategy.undeploy, which reduces deployedAssets only by the amount returned.
> This withdrawal leaves the whole booked-to-live shortfall behind, and the next harvest charges that loss to remaining holders.
> Answer yes only if a finding describes both code behaviors and explains how their combination shifts the loss.
> Accept equivalent descriptions without exact function names, amounts, or severity.
> Answer no if a finding gives only stale valuation and the resulting harm, without the live withdrawal and bookkeeping behavior.
> Do not infer a missing code behavior from the stated harm or from a proposed repair.

### 2. `sold_rewards_skip_fee_and_unlock`

`half-only-rewards` received yes instead of no.
It names `sellRewards`, `claimRewards`, the swap into idle USDC, and the fee and depositor harm.
It omits `totalAssets` counting that USDC immediately and `_harvest` charging fees and locking income.
The judge inferred the omitted profit-lock behavior from the one-block capture claim.

Proposed replacement description:

> The file holds an audit report on the Sluice contracts.
> The known vulnerability combines reward sales into idle USDC with a separate harvest accounting path.
> SluiceVault.sellRewards claims strategy incentives and leaves their swap proceeds in idle USDC, which totalAssets counts immediately.
> SluiceVault._harvest charges performance fees and locks net income for PROFIT_UNLOCK_TIME, but those sale proceeds bypass this path.
> This combination denies the treasury its fee and lets a depositor capture existing holders' income around a reward sale.
> Answer yes only if a finding describes both code behaviors and explains how the sale bypasses fee and profit-lock accounting.
> Accept equivalent descriptions without exact function names, amounts, or severity.
> Answer no if a finding gives only the reward sale path and resulting harm without the immediate valuation and harvest accounting behavior.
> Do not infer missing accounting behavior from a fee-loss claim, a one-block capture claim, or a proposed repair.

## Method and checks

The check reused `judge-check/check_judges.py` through `check-audit-vault.py`.
The source task was `/Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks/tasks/build/audit-vault`.
All scratch cases are under `judge-check-2/audit-vault/`.

The reference exactly matches the report heredoc in `solution/solve.sh`.
The half-only reports name one code half and the right harm, without describing the other half or their combination.
The same-harm reports use different mechanisms: withdrawal rounding and direct USDC donations.
These are synthetic negative controls, not further claims about the source contracts.
The missing report contains exactly `No findings.md was written.`

Each scratch judge changed only its findings-file path.
Criteria, scoring, model, reasoning effort, and guard settings match the source.
The scratch suites omit the fixed-container-path `report.py` check and its scoring table, as the earlier check did.
The root reward retains `all-pass` aggregation.
The missing case checks judge behavior on the fallback text, not the separate report-presence check.

The judge was `anthropic/claude-opus-5-5` at high reasoning effort, with one sample per report.
The prior runner reserves each call's cost before sending it, caps output at 4,096 tokens, and disables transport retries.
All six calls ended with `stop` below that output cap.
All guard checks were false, with no saved errors or warnings.
SHA-256 hashes match for every source task file before and after the check.
No source task file changed.

`check-audit-vault-results.py` checks the saved verdicts, copied configuration, ledger costs, completion status, guard results, and source hashes.
This check measures one model response per report; it does not establish consistency across repeated calls.

## Spend and artifacts

Costs come from RewardKit's `usage.cost_usd`, not a provider billing export.

| Report | Reported API cost |
| --- | --- |
| reference | $0.019436 |
| half-only-loss | $0.018540 |
| half-only-rewards | $0.017604 |
| same-harm-loss | $0.013432 |
| same-harm-rewards | $0.016376 |
| missing | $0.011484 |
| Total | $0.096872 |

Each case contains `findings.md`, copied tests, `reward.json`, and `reward-details.json`.
`audit-vault/expectations.json` records expectations frozen before the calls.
`audit-vault/calls.jsonl` records each call's reserve, usage, cost, and finish reason.
`audit-vault/source-hashes.json` records the source task hashes.

The paid command ran from the source worktree:

```sh
uv run --env-file /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks/.env python /tmp/subagents/security-audit-tasks/judge-check-2/check-audit-vault.py --run
```

The saved-result check used:

```sh
uv run python /tmp/subagents/security-audit-tasks/judge-check-2/check-audit-vault-results.py
```
