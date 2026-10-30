# DeFi composability, callbacks, oracles, and chain differences

There are 12 candidates, including three rated high for cold frontier-model failure. No model trials were run.
Research used 40 searches or page fetches, counting each requested query or URL separately.
The strongest candidates concern reversible liquidity rounding, nested v4 unlocks, and low-gas transient writes.

### defi-hook-forwarder-authentication
**Instruction:**
Can this router safely trust the callback? You are reviewing a Uniswap v4 integration. The router accepts `corkCall` only from its configured hook. That hook exposes `beforeSwap` without checking `msg.sender` and forwards a caller address and market ID from `hookData` to the router. Its developer says the router's caller check authenticates the whole path. Answer yes or no, then explain in one sentence.

**Answer:** No. An attacker can call the hook directly and use it to forward forged parameters through the router's trusted caller.

**Why a model gets it wrong:** It treats authentication of the final caller as authentication of the full call path. A frontier model can still spot the missing check, so failure confidence is medium.

**Backing:** Cork, May 28, 2025, 3,761 wstETH extracted; the hook passed forged callback data to its trusted router. https://www.cork.tech/blog/post-mortem

**Spec source:** Cork's technical account, sections 5 and 9, identifies the missing hook authorization and downstream caller check. https://www.cork.tech/blog/post-mortem

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### defi-hook-rounding-composition
**Instruction:**
Does the rounding argument establish that this AMM is safe? You are reviewing a Uniswap v4 hook. Tiny withdrawals round the pool's idle balance up, so they understate its active liquidity. The hook chooses the smaller of two token-based liquidity estimates. A later swap can change which estimate it chooses and reverse that understatement. The developer argues that lower liquidity always favors the pool because traders face more price impact. Answer yes or no, then explain in one sentence.

**Answer:** No. A swap can restore understated liquidity between two trades, which lets an attacker profit from the inconsistent liquidity estimates.

**Why a model gets it wrong:** It applies a local rule that rounding against the withdrawing user protects the pool to a sequence that changes liquidity estimates.

**Backing:** Bunni, September 2, 2025, about $8.4 million; repeated tiny withdrawals distorted liquidity before profitable swaps. https://blog.bunni.xyz/posts/exploit-post-mortem/

**Spec source:** The report's withdrawal calculation and two-estimate liquidity calculation fix the behavior. https://blog.bunni.xyz/posts/exploit-post-mortem/

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** high

### defi-v4-flash-liquidity-composability
**Instruction:**
Can this transaction complete? You are reviewing an attack simulation against a Uniswap v4 hook vault. The attacker obtains temporary tokens through `PoolManager.unlock`, then calls a vault withdrawal before returning from `unlockCallback`. The withdrawal unconditionally calls `unlock` on the same PoolManager again. Assume there is enough liquidity and every token debt can be repaid. Answer yes or no, then explain in one sentence.

**Answer:** No. The nested `unlock` reverts because the same PoolManager is already unlocked.

**Why a model gets it wrong:** It assumes flash accounting permits arbitrary nested operations if the final balances settle. It can confuse operations inside one unlock with a second unlock.

**Backing:** Bunni's September 2025 post-mortem explains why Uniswap v4 could not supply the flash liquidity needed for withdrawals in the same exploit. https://blog.bunni.xyz/posts/exploit-post-mortem/

**Spec source:** PoolManager's `unlock` rejects an already unlocked manager with `AlreadyUnlocked`. https://github.com/Uniswap/v4-core/blob/main/src/PoolManager.sol

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** high

### defi-fresh-composed-feed
**Instruction:**
Do these checks rule out a catastrophic collateral overvaluation? You are reviewing a lending market that multiplies an ETH/USD feed by a liquid staking token's token/ETH market-price feed. Both answers are positive, both have the expected decimals, and both updated seconds ago. The token/ETH feed now reports more than a million ETH per token after its trading liquidity collapses. The contract has no independent price bound. Answer yes or no, then explain in one sentence.

**Answer:** No. Freshness and decimal checks cannot establish that a component market price is economically valid.

**Why a model gets it wrong:** Likely known. The useful distinction is a fresh but false component answer rather than a stale feed or a decimal mismatch.

**Backing:** Moonwell's November 4, 2025 wrsETH incident created $3.7 million in bad debt; its risk manager reported a token/ETH answer above 1.6 million. The report does not establish the feed's precise internal failure mechanism. https://forum.moonwell.fi/t/wrseth-oracle-malfunction-11-4-25/2017

**Spec source:** The risk manager documents multiplication of ETH/USD and wrsETH/ETH and the later switch to exchange-rate oracles. https://forum.moonwell.fi/t/wrseth-oracle-malfunction-11-4-25/2017

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

### defi-read-only-staticcall
**Instruction:**
Can the lending market still suffer an inflated collateral valuation? You are reviewing a market that prices Curve LP collateral with `get_virtual_price()`. Every state-changing entry point in both protocols has a working reentrancy guard. During Curve's ETH withdrawal callback, the LP supply has fallen but not all underlying tokens have left the pool. The attacker calls the lending market, which reads the unguarded price through `STATICCALL`. Answer yes or no, then explain in one sentence.

**Answer:** Yes. The static read can observe inconsistent pool balances and LP supply, and the lending market can act on that inflated price.

**Why a model gets it wrong:** It treats a static read and local state-changing guards as protection against an inconsistent price from another contract. Likely known, though the working guards remove the usual single-function explanation.

**Backing:** ChainSecurity disclosed Curve LP oracle manipulation to affected teams on April 14, 2022 and published it on October 11, 2022. Several integrations had funds at risk; this report documents prevention, not a realized loss. https://www.chainsecurity.com/blog/curve-lp-oracle-manipulation-post-mortem/

**Spec source:** The disclosure includes the withdrawal order and the `get_virtual_price` calculation. https://www.chainsecurity.com/blog/curve-lp-oracle-manipulation-post-mortem/

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** medium

### defi-permissionless-factory-trust
**Instruction:**
Does this admission check justify trusting a market's reward callbacks? You are reviewing a yield aggregator that accepts any market for which Pendle's official market factory returns `isValidMarket(market) == true`. The aggregator then claims rewards through that market and treats its underlying Standardized Yield contract as trusted code. Market creation through the factory is permissionless. Answer yes or no, then explain in one sentence.

**Answer:** No. Official factory provenance does not establish trust in the underlying Standardized Yield contract chosen by a permissionless creator.

**Why a model gets it wrong:** It confuses an authentic protocol market with a vetted underlying asset. Likely known once the instruction makes permissionless creation explicit.

**Backing:** Penpie, September 3, 2024 UTC, about $27 million; a malicious Standardized Yield contract entered through permissionless market registration. Zokyo had audited an earlier version and published this analysis. https://zokyo.io/blog/penpie-postmortem/

**Spec source:** Zokyo reproduces the factory admission check and explains the attacker-controlled underlying contract. https://zokyo.io/blog/penpie-postmortem/

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

### defi-global-leverage-window
**Instruction:**
Is the manager's guard sufficient to keep the vault and shorts tracker consistent? You are reviewing GMX v1-style contracts. A position manager updates a separate shorts tracker, enables leverage in the vault, executes an order through an order book, and disables leverage afterward. The order book sends native ETH to the user during execution. Vault position entry points remain callable while leverage is enabled and do not update the separate tracker. The manager itself uses `nonReentrant`. Answer yes or no, then explain in one sentence.

**Answer:** No. The ETH recipient can call the vault during the enabled interval and change positions without the manager's shorts-tracker update.

**Why a model gets it wrong:** It reads the manager's reentrancy guard as a boundary around a privilege shared by several contracts. The temporary global permission is the key distinction.

**Backing:** GMX v1 on Arbitrum, July 9, 2025, about $40 million; cross-contract reentrancy allowed GLP valuation manipulation. GMX's governance forum confirms the incident; OpenZeppelin supplies the technical analysis. https://gov.gmx.io/t/discussion-resolve-the-distribution-plan-for-the-recovered-funds-from-arbitrum-glp/4678 and https://www.openzeppelin.com/news/web3-security-auditors-2025-rewind

**Spec source:** OpenZeppelin's section on GMX describes the tracker, leverage interval, ETH callback, and inconsistent accounting. This is a researcher analysis; no pinned GMX source revision was checked. https://www.openzeppelin.com/news/web3-security-auditors-2025-rewind

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### defi-donation-health-check
**Instruction:**
Must this donation path check the donor's account health? You are reviewing a lending protocol where `donateToReserves` burns a borrower's collateral receipt tokens and credits the reserves. It does not reduce the borrower's debt or transfer underlying tokens out. Liquidation gives a discount that increases as account health falls. Another account controlled by the donor can liquidate the resulting position. Answer yes or no, then explain in one sentence.

**Answer:** Yes. Burning collateral can create a profitable self-liquidation even though the donation sends no underlying assets to the donor.

**Why a model gets it wrong:** Likely known. The stale belief is that a voluntary donation cannot harm the protocol because it adds to reserves.

**Backing:** Euler v1, March 13, 2023, about $197 million; Euler identifies the missing donation health check and deliberate eligibility for liquidation. https://www.euler.finance/blog/war-peace-behind-the-scenes-of-eulers-240m-exploit-recovery

**Spec source:** Euler's own account describes the donation and liquidation mechanism. The instruction fixes the simplified accounting and discount assumptions. https://www.euler.finance/blog/war-peace-behind-the-scenes-of-eulers-240m-exploit-recovery

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** low

### defi-transient-lock-batch
**Instruction:**
Does the second withdrawal succeed or revert? You are reviewing a vault's multicall support. Each successful `withdraw` checks that transient slot `LOCK` is zero, writes one, completes its transfer, and returns without clearing `LOCK`. The developer relies on EIP-1153 to clear it. A router calls `withdraw` twice sequentially in one transaction, with enough shares and assets for both. Answer succeed or revert, then explain in one sentence.

**Answer:** Revert. EIP-1153 clears transient storage at transaction end, so the second call still sees the first call's lock.

**Why a model gets it wrong:** It treats transient storage as call-local memory or assumes a reentrancy lock only affects nested calls. Likely known to a frontier model familiar with EIP-1153.

**Backing:** The Solidity team's January 26, 2024 transient storage disclosure explicitly clears its sample lock to preserve repeated calls within one transaction. This is a disclosed composability hazard, with no loss reported. https://soliditylang.org/blog/2024/01/26/transient-storage/

**Spec source:** EIP-1153, specification on transaction lifetime; Solidity's sample lock clears its slot before return. https://eips.ethereum.org/EIPS/eip-1153 and https://soliditylang.org/blog/2024/01/26/transient-storage/

**Grading:** pattern: starts with revert

**Your confidence a frontier model fails cold:** medium

### defi-transient-lock-delegatecall
**Instruction:**
Does the second module enter or revert? You are reviewing a diamond proxy's reentrancy protection. Module A and module B use EIP-1153 locks at the same transient slot. The proxy runs both modules through `DELEGATECALL`. While A holds its lock, an external callback reenters the proxy and selects B. B checks that slot before doing any work. Assume no other checks fail. Answer enter or revert, then explain in one sentence.

**Answer:** Revert. Both delegatecalls use the proxy's transient storage, so B reads the lock that A set.

**Why a model gets it wrong:** It treats distinct module addresses as distinct transient stores. A second error is recommending different lock slots even when the modules must protect shared state.

**Backing:** The Solidity team's January 2024 disclosure describes keyed locks for shared data and the bugs caused by choosing the wrong lock boundaries. This candidate applies that disclosed design hazard to proxy modules; it is not a named proxy exploit. https://soliditylang.org/blog/2024/01/26/transient-storage/

**Spec source:** EIP-1153 assigns transient storage to the caller's context under `DELEGATECALL`. https://eips.ethereum.org/EIPS/eip-1153

**Grading:** pattern: starts with revert

**Your confidence a frontier model fails cold:** medium

### defi-transient-low-gas-callback
**Instruction:**
Can the callback change the pending allowance? You are reviewing an exchange that records a pending temporary allowance in transient storage before sending ETH to a user with Solidity's `transfer`. During the recipient's 2,300-gas callback, the recipient reenters an unguarded exchange function whose only effect is a `TSTORE` to that allowance. Assume its dispatch and write fit within the stipend. The exchange reads the allowance afterward. Answer yes or no, then explain in one sentence.

**Answer:** Yes. `TSTORE` lacks the low-gas restriction that prevents `SSTORE` under the transfer stipend.

**Why a model gets it wrong:** It extends the historical persistent-storage argument for `transfer` to transient storage. The instruction fixes the gas budget, so exact opcode-cost arithmetic is unnecessary.

**Backing:** ChainSecurity disclosed working low-gas transient-storage attacks on November 10, 2023, including temporary allowance manipulation. No production loss is claimed. https://www.chainsecurity.com/blog/tstore-low-gas-reentrancy/index.html

**Spec source:** EIP-1153 excludes `TSTORE` from the EIP-2200 stipend restriction; ChainSecurity supplies executable demonstrations. https://eips.ethereum.org/EIPS/eip-1153 and https://www.chainsecurity.com/blog/tstore-low-gas-reentrancy/index.html

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** high

### defi-proposal-age-flash-votes
**Instruction:**
Does the proposal delay prevent a flash-loan takeover? You are reviewing DAO treasury governance. A proposal must exist for 24 hours before emergency execution. Emergency approval uses voters' current deposited balances, credited immediately, with no past voting snapshot or holding period. If the threshold is reached, execution transfers treasury assets immediately and the voter can withdraw its deposit in the same transaction. An attacker created its proposal yesterday. Answer yes or no, then explain in one sentence.

**Answer:** No. The attacker can acquire the voting balance, approve and execute the aged proposal, and repay the flash loan atomically.

**Why a model gets it wrong:** Likely known. The narrower error is treating proposal age as a holding period for the voting assets.

**Backing:** Beanstalk, April 17, 2022; its DAO-commissioned investigation confirms a flash-loan governance takeover. Beosin's contemporary technical investigation describes the day-old proposal and emergency execution. https://img1.wsimg.com/blobby/go/84879eef-009a-49e3-bec7-d2ea2f962a66/Public%20Version%20-%20Investigation%20IOC-Bea-99b5063.pdf and https://official.beosin.com/resources/beosins-analysis-of-the-beanstalk-exploit

**Spec source:** Beosin's investigation documents `emergencyCommit`; the instruction states the simplified proposal and voting rules explicitly. https://official.beosin.com/resources/beosins-analysis-of-the-beanstalk-exploit

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

## Rejected on the way

- Classic single-function reentrancy: excluded by the brief and likely known.
- Curve's July 2023 compiler incident as read-only reentrancy: conflates separate bugs; the retained candidate uses ChainSecurity's actual read-only disclosure.
- Later Curve read-only repeats: found a Curve-hosted StableSwapNG audit finding, but did not read enough to draft a distinct candidate. https://docs.curve.finance/assets/pdf/audits/Curve%20Finance%20StableSwapNG%20Security%20Audit%20Report.pdf
- Uniswap v3 callback caller authentication: likely known; no exact primary incident was verified within the budget.
- V4 hook permission bits: verified that `Hooks.sol` reads address flags; a deployment-bit question risks the forbidden address-grinding exercise. https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol
- V4 hook swap powers: the code defines returned-delta permissions and guards against changing exact-input into exact-output; no matching incident was verified. https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol
- V4 hook self-call suppression: found `noSelfCall` in the source, but did not verify an incident where this exact rule caused harm.
- Cork market identity checks as a second candidate: the report's central callback flaw was missing hook caller authentication; avoid inventing a different root cause.
- Bunni as a liquidity-rebalancing exploit: its own post-mortem explicitly rejects that account; the retained candidate concerns rounding and liquidity estimates.
- ERC20Votes self-delegation: likely known; no exact incident or audit finding was verified, so Beanstalk is not used as substitute backing.
- Timelock bypass through proposal execution details: no specific implementation and primary disclosure were checked; retained only the explicit proposal-age case.
- Chainlink stale data and feed decimals: the API reference confirms answer timestamps and per-feed decimals, but these are likely known. https://docs.chain.link/data-feeds/api-reference
- Chainlink min/max answer circuit breakers and Venus/LUNA: found contemporary reports of the feed floor, but did not verify the incident against Venus's own account; no candidate asserts that current feeds universally clamp answers.
- Chainlink L2 sequencer recovery: read the uptime-feed docs, but found no exact loss or disclosed bug backing a distinct candidate. https://docs.chain.link/data-feeds/l2-sequencer-feeds
- Deprecated feeds as Moonwell's established root cause: the official November report confirms the bad answer and oracle replacement; a forum reply alone does not prove deprecation caused it.
- Moonwell cbETH incident: the November 2025 report concerns wrsETH; do not merge the two events.
- Thin-liquidity TWAP manipulation: likely known; no distinct primary incident was checked beyond Cork's low-volume historical-price problem.
- Spot prices from reserves: likely known; Cork's broader economic path does not make a plain spot-price question hard enough.
- Arbitrum `block.number`: overlaps the supplied surviving instruction about the Governor clock.
- Arbitrum, Optimism, and Base `prevrandao`, timestamps, and block numbers: no chain-by-chain primary specification and matching incident were verified before the budget ended.
- L2 precompile availability: requires a named chain and fork revision; no matching primary incident was verified.
- `chainId` after a fork: no candidate without explicit fork assumptions and a verified incident; avoid implying that every fork changes it.
- LayerZero v2 endpoint and peer authentication: no exact v2 incident was verified; avoid attaching an unrelated bridge exploit.
- CCIP sender, source-chain selector, replay, and finality assumptions: no exact primary disclosure was verified; generic cross-chain authentication is likely known.
