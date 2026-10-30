### tokens-exact-output-rate-scaling
Verdict: CORRECT
Note: Up avoids charging for less output than the pool sends; OpenZeppelin confirms that rate scaling rounded exact-output amounts down in the [Balancer analysis](https://www.openzeppelin.com/news/understanding-the-balancer-v2-exploit).

### tokens-idle-balance-subtraction
Verdict: CORRECT
Note: Down rounds the decrement down and leaves the larger idle balance, as [Bunni's withdrawal analysis](https://blog.bunni.xyz/posts/exploit-post-mortem/) explicitly explains.

### tokens-conservative-liquidity-rounding
Verdict: CORRECT
Note: No follows because the argument ignores changes between operations; [Bunni's report](https://blog.bunni.xyz/posts/exploit-post-mortem/) confirms that reversing the underestimate enabled a profitable sandwich.

### tokens-virtual-shares-zero-share-deposit
Verdict: AMBIGUOUS
Note: A careful auditor can defend Yes for an already funded vault: starting with 1,000,000 assets and shares gives this user 4,950 shares. [OpenZeppelin's formula](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/extensions/ERC4626.sol#L213-L220) supports the intended zero only with an initially empty vault, which the instruction never states.

### tokens-virtual-offset-oracle-price
Verdict: CORRECT
Note: No follows from the supplied formula: donations increase assets without increasing shares, and a fixed offset imposes no economic price cap. [OpenZeppelin's conversion code](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/extensions/ERC4626.sol#L218-L220) confirms the formula; the instruction does not claim every ERC-4626 vault uses it.

### tokens-inverse-price-zero-solvency
Verdict: CORRECT
Note: No follows from integer division: any price above 1e36 makes the reciprocal and calculated LTV zero. [Resupply's report](https://paragraph.com/@resupply/xXNoMg4iByksss66igix) reproduces both expressions and this failure.

### tokens-empty-market-seed-order
Verdict: CORRECT
Note: No follows because separate permissionless executions leave a usable collateral market before seeding. [ChainSecurity's exchange-rate expression](https://www.chainsecurity.com/blog/trueusd---compound-vulnerability) confirms the donation-sensitive ratio; its full formula also includes borrows and reserves, initially zero in this scenario.

### tokens-accumulator-muldiv-rounding
Verdict: CORRECT
Note: No follows because full precision preserves the final floor, so withdrawals can burn too few raw units. [BlockSec's analysis](https://blocksec.com/blog/zklend-exploit-post-mortem-unraveling-the-details-and-clarifying-misunderstandings-of-the-10m-flash-loan-attack) confirms accumulator inflation and underestimated burns; the instruction defines mulDiv without relying on a particular library.

### tokens-tick-crossing-input-threshold
Verdict: LEAKS
Note: "No relation between the rounding errors has been proved" supplies the reason to reject the purported proof. The intended No matches [KyberSwap's report](https://blog.kyberswap.com/post-mortem-kyberswap-elastic-exploit/), but the instruction exposes the missing proof obligation directly.

### tokens-zero-invariant-reinitialization
Verdict: LEAKS
Note: "The internal supply can reach zero while ERC-20 LP balances remain" gives the counterexample behind the answer. No matches [Yearn's disclosure](https://github.com/yearn/yearn-security/blob/master/disclosures/2025-12-01.md#consolidated-root-causes), but the instruction supplies the central distinction instead of asking the auditor to find it.

### tokens-double-entry-rescue
Verdict: CORRECT
Note: No follows because the address check permits the legacy entry point, which drains the same balance to the administrator. [ChainSecurity's disclosure](https://www.chainsecurity.com/blog/trueusd---compound-vulnerability) describes precisely this rescue-function failure.

### tokens-convert-assets-mint-quote
Verdict: CORRECT
Note: No matches [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626#previewmint): conversion excludes fees and floors, while previewMint includes deposit fees and cannot understate the required assets. These are standard requirements, not OpenZeppelin-specific behavior.

### tokens-steth-exact-receipt
Verdict: CORRECT
Note: Yes matches [Lido's documented transfer rounding](https://docs.lido.fi/guides/lido-tokens-integration-guide/#1-2-wei-corner-case), even without a rebase or fee. The instruction names the library-specific safeTransferFrom helper, but the answer depends on stETH accounting and remains true with an ordinary successful transferFrom.

### tokens-wrapped-staking-unit-reuse
Verdict: CORRECT
Note: No is correct for the adapter's general behavior because it reuses a wstETH quantity as a stETH quantity. [Lido's guide](https://docs.lido.fi/guides/lido-tokens-integration-guide/) confirms that each wstETH represents a changing amount of stETH; specifying an amount above dust avoids integer-rounding edge cases.

### defi-hook-forwarder-authentication
Verdict: CORRECT
Note: No follows because anyone can make the trusted hook forward attacker-chosen data. [Cork's report](https://www.cork.tech/blog/post-mortem) confirms the missing hook authorization and the resulting access to privileged router functions.

### defi-hook-rounding-composition
Verdict: CORRECT
Note: No matches [Bunni's report](https://blog.bunni.xyz/posts/exploit-post-mortem/): a switch between liquidity estimates reversed the earlier decrease and enabled a sandwich. The instruction correctly describes the resulting idle balance as rounded up, although the subtracted withdrawal amount rounded down.

### defi-v4-flash-liquidity-composability
Verdict: CORRECT
Note: No matches [PoolManager.unlock](https://github.com/Uniswap/v4-core/blob/main/src/PoolManager.sol), which raises AlreadyUnlocked when called during an existing unlock. State that the caller propagates the revert if the question must distinguish a failed withdrawal from a transaction that catches its failure.

### defi-fresh-composed-feed
Verdict: LEAKS
Note: "More than a million ETH per token" and "no independent price bound" already describe the unchecked overvaluation that the question asks the auditor to detect. No matches [Moonwell's report](https://forum.moonwell.fi/t/wrseth-oracle-malfunction-11-4-25/2017), but that report does not establish the instruction's claimed trading-liquidity collapse.

### defi-read-only-staticcall
Verdict: CORRECT
Note: Yes matches [ChainSecurity's disclosure](https://www.chainsecurity.com/blog/curve-lp-oracle-manipulation-post-mortem/): the price read observes reduced LP supply before all assets leave. A local lending-market guard need not be held when Curve calls the attacker, and STATICCALL does not require consistent external accounting.

### defi-permissionless-factory-trust
Verdict: CORRECT
Note: No matches [Zokyo's reproduced admission check](https://zokyo.io/blog/penpie-postmortem/): isValidMarket proves factory provenance but permits an attacker-controlled Standardized Yield contract. The named protocol behavior is explicit, with no hidden library assumption.

### defi-global-leverage-window
Verdict: CORRECT
Note: No follows because the vault remains callable independently of the manager's guard and tracker update. [OpenZeppelin's GMX analysis](https://www.openzeppelin.com/news/web3-security-auditors-2025-rewind) confirms the leverage interval, ETH callback, and direct vault position change.

### defi-donation-health-check
Verdict: AMBIGUOUS
Note: A careful auditor can defend No if the increasing liquidation discount never awards more than the donor forfeits and reserves cover the lost collateral. [Euler's report](https://www.euler.finance/blog/war-peace-behind-the-scenes-of-eulers-240m-exploit-recovery) establishes that its bonus exceeded the donation, but the instruction omits the discount formula and this crucial inequality.

### defi-transient-lock-batch
Verdict: CORRECT
Note: Revert follows from [EIP-1153's transaction lifetime](https://eips.ethereum.org/EIPS/eip-1153#specification): the first successful call leaves LOCK set for the second call. [Solidity's example](https://www.soliditylang.org/blog/2024/01/26/transient-storage/) explicitly clears the lock to permit repeated calls.

### defi-transient-lock-delegatecall
Verdict: CORRECT
Note: Revert follows from [EIP-1153's ownership rules](https://eips.ethereum.org/EIPS/eip-1153#specification): both delegated modules access the proxy's transient storage and therefore the same lock. Different implementation addresses do not separate storage under DELEGATECALL.

### defi-transient-low-gas-callback
Verdict: CORRECT
Note: Yes matches [EIP-1153](https://eips.ethereum.org/EIPS/eip-1153#specification) and [ChainSecurity's demonstration](https://www.chainsecurity.com/blog/tstore-low-gas-reentrancy/index.html): TSTORE has no SSTORE-style stipend restriction. The instruction supplies the remaining gas-feasibility assumption, so no exact opcode budget is missing.

### defi-proposal-age-flash-votes
Verdict: CORRECT
Note: No follows because only the proposal must age, while voting assets can enter and leave during execution. [Beosin's investigation](https://official.beosin.com/resources/beosins-analysis-of-the-beanstalk-exploit) confirms the day-old proposal, current-balance votes, emergencyCommit, and atomic loan repayment.
