## Rejected on the way

- The earlier draft of `accounts-relayed-wallet` in this folder (from a run that stopped at 03:28) used an unsigned `baseGas` refund and a CREATE2 salt that omits the module; dropped as too close to `accounts-unsigned-gas-fields` and `upgrades-create2-front-run-owner`. Replaced with Biconomy H-07 (unsigned lane) and Ambire M-02 (relayer-forced failure).
- Synthetix-style staking rewards (rewards lost while supply is zero, permissionless `notifyRewardAmount` dust): the published findings are on Codehawks and Immunefi, judges split on validity, and the Cantina Botanix finding was not verified; reward-index topics are already asked (`rewards-zero-balance-skips-index`, `rewards-transfer-keeps-old-index`).
- NextGen M-07 (winner's `safeTransferFrom` callback blocks settlement) as the third auction issue: same kind as the push-refund issue. M-10 (bid stranded in the end second): same root as H-02, so folded into issue 1.
- Bridge message hash without destination chain: no published finding found within budget; the setup sentence on the prover closes it instead.
- Taiko M-12 (invocation delay not honoured after unpause): title only, details not verified.
- Renzo H-01 (`transfer` to contract recipients): already covered by `evm-transfer-*` topics.
- Biconomy H-03 (counterfactual wallet salt) and H-06 (`tokenGasPriceFactor` unsigned): covered by asked topics.

