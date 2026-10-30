# Audit judge check

All 21 criterion verdicts matched their expected answers. There were 0 misgrades across 12 model calls.
RewardKit reported a total cost of $0.151056, below the $3 cap.

## Method

The check used the worktree's uv environment and `harbor-rewardkit==0.2.3`.
`uv run rewardkit --help` confirmed the local tests-directory, workspace, and output arguments.
Each task had three scratch copies of its tests folder, one per report.
Each copied judge read that copy's `findings.md`.
The check removed the copied `report.py` and its `[scoring.report]` table because they use a fixed container path.
The root reward retained `all-pass` aggregation.
No criterion wording, names, weights, model, effort, guard, or judge aggregation changed.

The reference reports exactly match the heredocs in each task's `solution/solve.sh`.
Each near-miss report contains one finding per criterion, with the same contract and a different mechanism.
These findings are synthetic negative controls, not additional claims about the contracts.
Every missing report contains exactly `No findings.md was written.`

The runner calls RewardKit's `run()` function, which the CLI also uses.
A wrapper limits each response to 4,096 tokens and disables transport retries.
Before each call, it reserves input and output cost against the $3 cap.
The input reserve includes the schema and 4,096 extra tokens for framing.
The ledger replaces each completed call's reserve with RewardKit's reported cost.
All calls ended with `stop`. No response reached the limit, raised an error, or produced a warning.
All guard checks returned false.
SHA-256 checks found no changes in any file within the four source task folders.

The check uses one sample per report and one model.
It does not measure agreement across repeated calls or models.
The near-misses cover the written mechanisms only.

## Verdicts

Reasons below copy the judge's text. Full outputs remain in each case's `reward-details.json`.

| Task | Report | Criterion | Verdict | Expected | Judge reason |
| --- | --- | --- | --- | --- | --- |
| audit-staking | reference | `harvest_streams_queued_withdrawals` | yes | yes | H-01 names this exact mechanism. harvest() computes new rewards as balance minus storedAssets minus unvestedRewards() and never subtracts totalQueued. It notes that anyone can call harvest() and that FeeRouter.distribute() calls it on every fee run. The queued BLST is streamed to the remaining stakers, and the last claimWithdrawal() calls revert. The proposed fix subtracts totalQueued, which would also fix the known vulnerability. |
| audit-staking | reference | `queued_withdrawal_escapes_slash` | yes | yes | H-02 names this exact mechanism. requestWithdrawal() fixes the amount owed at request time, slash() only reduces storedAssets, and claimWithdrawal() pays the fixed amount. The public proposal delay in ShortfallModule lets a staker queue after a slash is proposed and escape it. The finding cites the README's pro-rata promise and the 30% cap reducing what the market recovers. |
| audit-staking | near-miss | `harvest_streams_queued_withdrawals` | no | no | H-01 covers harvest(), but its subject is front-running a deposit to capture rewards just before the harvest. It does not say that harvest's reward calculation leaves out totalQueued, which is the cause of queued BLST being streamed as rewards. Fixing H-01 would not fix the known bug. |
| audit-staking | near-miss | `queued_withdrawal_escapes_slash` | no | no | H-02 is about slash amounts not being checked against proven bad debt. It does not mention that queued withdrawals are priced when they are queued and are skipped by slash(), so a staker can queue after a slash proposal and avoid the cut. That mechanism is absent from the report. |
| audit-staking | missing | `harvest_streams_queued_withdrawals` | no | no | No report was written. The submission says no findings.md exists, so no finding names the harvest/totalQueued mechanism. |
| audit-staking | missing | `queued_withdrawal_escapes_slash` | no | no | No report was written, so no finding covers queued withdrawals escaping a slash. |
| audit-governance | reference | `cancelled_proposal_still_executes` | yes | yes | H-1 describes this exact mechanism. TideGovernor.cancel sets canceled without calling TideTimelock.cancel, and TideTimelock.execute is open to anyone and only checks timestamps[id]. The finding also gives the impact of a cancelled queued proposal still executing after the delay. |
| audit-governance | reference | `early_exit_keeps_voting_power` | yes | yes | H-2 describes this exact mechanism. exitEarly deletes the lock without writing a checkpoint, getPastVotes reads the stale checkpoint, and the governor counts that power in propose and castVote. The finding also covers relocking the returned TIDE from another address to double-vote and drain the treasury. |
| audit-governance | near-miss | `cancelled_proposal_still_executes` | no | no | H-1 is about who may call TideGovernor.cancel, meaning a bad guardian role assignment. It never says that cancel fails to call TideTimelock.cancel or that a cancelled queued operation can still run through TideTimelock.execute. Fixing the role assignment would not unschedule cancelled operations in the timelock. |
| audit-governance | near-miss | `early_exit_keeps_voting_power` | no | no | H-2 describes reentrancy in VoteEscrow.exitEarly that allows a double withdrawal. It does not mention the missing checkpoint after exit or getPastVotes returning stale voting power. Adding a reentrancy guard would not cause a new checkpoint to be written, so the stale voting power remains. |
| audit-governance | missing | `cancelled_proposal_still_executes` | no | no | The submission says no findings.md was written. There is no report, so nothing names the governor-cancel/timelock-execute mechanism. |
| audit-governance | missing | `early_exit_keeps_voting_power` | no | no | No report exists, so no finding describes the missing checkpoint in exitEarly or the voting power it leaves behind. |
| audit-vault | reference | `undeploy_keeps_harvest_baseline` | yes | yes | H-1 states that undeploy does not lower deployedAssets, the baseline that harvest measures profit against. It traces the path through _ensureIdle and deallocate, and gives the matching example of a 150,000 loss with no fee. Same mechanism on the same code path. |
| audit-vault | reference | `accrued_fees_in_total_assets` | yes | yes | H-2 states that _harvest books the fee as accruedFees but leaves the USDC in the vault, and that totalAssets does not subtract accruedFees. Redeemers before claimFees therefore take part of the treasury's fee, and the depositors who stay make up the difference. Same mechanism on the same code path. |
| audit-vault | near-miss | `undeploy_keeps_harvest_baseline` | no | no | H-1 covers BaseStrategy.undeploy, but its subject is external withdrawal slippage and missing minimum-return checks. It never says that undeploy fails to lower deployedAssets, which leaves harvest's baseline inflated and loses the performance fee. Fixing slippage would not fix the stale baseline. |
| audit-vault | near-miss | `accrued_fees_in_total_assets` | no | no | H-2 covers SluiceVault.totalAssets inflating the share price, but the cause it names is double-counted strategy valuations. It never says that accruedFees, held as idle USDC, is not subtracted. Only the contract and the impact match, not the mechanism. |
| audit-vault | missing | `undeploy_keeps_harvest_baseline` | no | no | No report was written, so no finding describes undeploy failing to lower the deployedAssets harvest baseline. |
| audit-vault | missing | `accrued_fees_in_total_assets` | no | no | No report was written, so no finding describes totalAssets including unclaimed accruedFees. |
| audit-dex | reference | `collected_fees_stay_tracked` | yes | yes | H-01 describes this exact mechanism. collectProtocolFees zeroes protocolFees and transfers the fees out without lowering trackedBalance, while _settle credits balance minus trackedBalance. The finding states the impact on later swaps and addLiquidity calls, the underflow reverts for small deposits, and the fact that the function is permissionless. Its proposed fix (use _send) would resolve the issue. |
| audit-dex | near-miss | `collected_fees_stay_tracked` | no | no | The report's only finding is about a missing authorization check on the fee recipient in collectProtocolFees. It never mentions that trackedBalance is not lowered after collection, or that this leaves the balance below trackedBalance. It also says nothing of the knock-on effects: later swaps and deposits being under-credited in _settle, or small deposits reverting on underflow. Fixing recipient authorization would not fix the trackedBalance accounting bug. |
| audit-dex | missing | `collected_fees_stay_tracked` | no | no | There is no report to evaluate. The submission only states that no findings.md was written, so no finding identifies the missing trackedBalance decrement in collectProtocolFees. |

## Misgrades and wording proposals

None. No criterion wording changes are proposed.

## Call costs

Costs come from RewardKit's normalized `usage.cost_usd` fields, not a provider billing export.

| Task | Report | Reported cost | Input tokens | Output tokens |
| --- | --- | --- | --- | --- |
| audit-staking | reference | $0.018876 | 2664 | 411 |
| audit-staking | near-miss | $0.013868 | 1937 | 306 |
| audit-staking | missing | $0.010104 | 1621 | 181 |
| audit-governance | reference | $0.015276 | 2224 | 319 |
| audit-governance | near-miss | $0.013768 | 1812 | 326 |
| audit-governance | missing | $0.009952 | 1523 | 193 |
| audit-vault | reference | $0.016544 | 2571 | 313 |
| audit-vault | near-miss | $0.014048 | 1977 | 307 |
| audit-vault | missing | $0.010224 | 1661 | 179 |
| audit-dex | reference | $0.011640 | 1790 | 224 |
| audit-dex | near-miss | $0.009704 | 1271 | 231 |
| audit-dex | missing | $0.007052 | 1103 | 132 |
| Total | 12 calls | $0.151056 | 22154 | 3122 |

## Artifacts and command

`calls.jsonl` records every API call's reserve, cost, token counts, and finish reason.
`source-hashes.json` records the source task files before the check.
Each case folder contains the report, copied tests, `reward.json`, and `reward-details.json`.
`check_judges.py` contains the bounded runner. `render_report.py` checks the saved results and prints this report.

The paid calls used this command from the source worktree:

```sh
uv run --env-file /Users/shivbhonde/Desktop/github/ethevals.security-audit-tasks/.env python /tmp/subagents/security-audit-tasks/judge-check/check_judges.py --remaining
```

The first reference case used `--case audit-staking reference` instead of `--remaining`.
The key stayed in the process environment and never appeared in tool output.
