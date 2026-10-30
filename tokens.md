# Token integration and share or vault math

Fourteen candidates. Three carry high confidence that a frontier model fails cold. These are estimates; no model trials have run. Amounts are approximate. Research used 40 web searches or fetches, including failed fetches and repeat reads. Nothing in the repository was edited.

### tokens-exact-output-rate-scaling
**Instruction:**
Which rounding direction must this exact-output swap use when it converts the requested token output to rate-adjusted units? You are reviewing a stable pool that supports yield-bearing tokens. It computes `adjustedOut = amountOut * rate / 1e18`, solves the invariant for the input owed, and transfers the original `amountOut` to the user. The rate can contain a fractional component, and balances can become tiny. Assume the remaining arithmetic favors the pool. Answer up or down, then explain in one sentence.

**Answer:** Up. Rounding the requested output down prices a smaller output than the pool transfers.

**Why a model gets it wrong:** It applies the rule to round assets paid out down, even though this intermediate value describes an exact output obligation.

**Backing:** Balancer v2 Composable Stable Pools, November 3, 2025, over $120 million across Balancer and forks. OpenZeppelin traced the undercharge to rate scaling with `mulDown`: https://www.openzeppelin.com/news/understanding-the-balancer-v2-exploit

**Spec source:** The same analysis reproduces `_upscale` and its caller; the direction follows from the exact-output obligation in the instruction.

**Grading:** pattern: starts with Up

**Your confidence a frontier model fails cold:** high

### tokens-idle-balance-subtraction
**Instruction:**
Which rounding direction leaves the larger idle balance after an LP withdrawal? You are reviewing a pool that computes `newIdle = oldIdle - mulDiv(oldIdle, burnedShares, totalShares)`. The multiplication and division use full precision, except for rounding the quotient. The pool treats idle tokens as unavailable for swaps, so the developer wants to avoid overstating active liquidity. Answer up or down, then explain in one sentence.

**Answer:** Down. Rounding the subtracted quotient down leaves more idle tokens and fewer active tokens in the accounting.

**Why a model gets it wrong:** It remembers Bunni as a case where idle balances rounded down and confuses the rounded decrement with the resulting balance.

**Backing:** Bunni, September 2, 2025. Its own post-mortem identifies this exact subtraction and explains why local conservatism failed across operations: https://blog.bunni.xyz/posts/exploit-post-mortem/

**Spec source:** The post-mortem's `BunniHubLogic::withdraw()` excerpt fixes the expression and rounding meaning.

**Grading:** pattern: starts with Down

**Your confidence a frontier model fails cold:** low

### tokens-conservative-liquidity-rounding
**Instruction:**
Can you approve this rounding argument for a pool before launch? Withdrawals deliberately underestimate active liquidity. Swaps use the smaller of two liquidity estimates, one derived from each token balance. A later swap can change which estimate is smaller and reverse the earlier underestimate within the same transaction. The developer argues that understating liquidity always protects the pool because it increases price impact. Answer yes or no, then explain in one sentence.

**Answer:** No. Reversing the underestimate between swaps can create a liquidity increase that an attacker captures with a sandwich.

**Why a model gets it wrong:** It treats every conservative local calculation as proof that the full operation sequence conserves value.

**Backing:** Bunni's September 2, 2025 exploit used repeated tiny withdrawals followed by swaps that reversed part of the liquidity underestimate: https://blog.bunni.xyz/posts/exploit-post-mortem/

**Spec source:** The same post-mortem explains the minimum of the token-derived liquidity estimates and the reversal during swaps.

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### tokens-virtual-shares-zero-share-deposit
**Instruction:**
Does this vault guarantee that the user's deposit receives at least one share? You are reviewing an ERC-4626 vault with `shares = floor(assets * (totalSupply + 1) / (totalAssets + 1))`. It reads `totalAssets` from the asset token balance. An attacker deposits 1 asset unit, then transfers 10,000 units directly to the vault without minting shares. The next user deposits 5,000 units. There are no fees or other transactions, and all amounts are raw integer units. Answer yes or no, then explain in one sentence.

**Answer:** No. The user receives `floor(5000 * 2 / 10002) = 0` shares despite the virtual asset and virtual share.

**Why a model gets it wrong:** It treats OpenZeppelin's virtual shares as a promise that no deposit can round to zero. The protection changes attack economics; it does not impose a minimum output.

**Backing:** OpenZeppelin's ERC-4626 v5.0.2 security warning expressly says virtual shares do not fully prevent the attack. This is a library disclosure and a calculated example, not a claim of a deployed OpenZeppelin-vault loss: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/extensions/ERC4626.sol

**Spec source:** The same file's `_convertToShares` adds `10 ** _decimalsOffset()` shares and one asset; its default offset is zero. The instruction states that exact formula.

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** high

### tokens-virtual-offset-oracle-price
**Instruction:**
Does this virtual-share defense bound the collateral price against direct donations? You are reviewing a lender that prices vault shares with `convertToAssets(10 ** shareDecimals)`. The vault computes assets as `floor(shares * (totalAssets + 1) / (totalSupply + 10 ** offset))`, reads `totalAssets` from its token balance, and sets a positive decimals offset. An attacker can transfer underlying tokens directly to the vault. The lender claims the offset caps the quoted price without any donation limit or price cap. Answer yes or no, then explain in one sentence.

**Answer:** No. A donation increases the numerator while the share denominator stays fixed, so the offset does not cap the quoted price.

**Why a model gets it wrong:** It extends the protection against first-depositor theft to collateral pricing. Increasing the cost of manipulation does not impose a bound.

**Backing:** Resupply's June 26, 2025 incident created 10 million reUSD of bad debt after vault-share inflation reached an unsafe downstream calculation: https://paragraph.com/@resupply/xXNoMg4iByksss66igix . The affected vault was not verified to use this exact OpenZeppelin offset formula; the incident backs the downstream integration risk, while the stated formula fixes this variant's answer.

**Spec source:** OpenZeppelin's `_convertToAssets` formula: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/extensions/ERC4626.sol . ERC-4626 does not require `convertToAssets` to resist donations: https://eips.ethereum.org/EIPS/eip-4626#security-considerations

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### tokens-inverse-price-zero-solvency
**Instruction:**
Does the zero-price guard protect this borrow check? You are reviewing a lender that rejects an oracle price of zero, then computes `exchangeRate = 1e36 / price`. It checks solvency using `ltv = debt * exchangeRate * LTV_PRECISION / EXCHANGE_PRECISION / collateral`, and accepts `ltv <= maxLTV`. A donation can raise the vault-share oracle price above `1e36`. Assume nonzero collateral and no multiplication overflow. Answer yes or no, then explain in one sentence.

**Answer:** No. A positive price above `1e36` makes the reciprocal round to zero, which makes the computed loan-to-value zero for every debt.

**Why a model gets it wrong:** It treats a positive oracle answer as sufficient or assumes an inflated collateral price only causes ordinary overvaluation. The critical zero appears after inversion.

**Backing:** Resupply, June 26, 2025, 10 million reUSD of bad debt. The protocol's post-mortem gives both expressions and the `1e36 / 2e36` result: https://paragraph.com/@resupply/xXNoMg4iByksss66igix

**Spec source:** The same first-party post-mortem reproduces the affected solvency code.

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** high

### tokens-empty-market-seed-order
**Instruction:**
Can you approve this activation sequence for a new Compound v2 lending market? A timelock exposes separate permissionless executions to list the market, enable its collateral factor, and seed it with permanently locked receipt tokens. After the delay, anyone can execute any ready operation. The team plans to execute them in that order during one maintenance session. The exchange rate uses the underlying token balance divided by receipt-token supply. Answer yes or no, then explain in one sentence.

**Answer:** No. An attacker can activate the unseeded collateral market before the seed operation and manipulate its exchange rate with dust shares and a donation.

**Why a model gets it wrong:** It credits a planned seed as protection without checking whether the activation and seed are atomic. Likely known once the ordering gap is explicit.

**Backing:** Sonne Finance, May 14, 2024, about $20 million. The new VELO market exposed an empty-market window through executable timelock operations: https://rekt.news/sonne-finance-rekt . Rekt is an incident source permitted by the brief, but it is not Sonne's own post-mortem; first-party verification of the deployment sequence remains incomplete.

**Spec source:** ChainSecurity reproduces Compound's exchange-rate expression `(totalCash + totalBorrows - totalReserves) / totalSupply`: https://www.chainsecurity.com/blog/trueusd---compound-vulnerability/ . The instruction fixes the executable operation semantics.

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### tokens-accumulator-muldiv-rounding
**Instruction:**
Does replacing ordinary multiplication and division with full-precision `mulDiv` fix this lending-market withdrawal? A user's raw balance represents assets as `rawBalance * accumulator / SCALE`. Withdrawals burn `mulDiv(assets, SCALE, accumulator)` raw units, rounded down. Empty-market flash-loan overpayments can inflate the accumulator far above `SCALE`. Deposits also round down, and there are no overflow errors. Answer yes or no, then explain in one sentence.

**Answer:** No. Full precision still rounds down, so an inflated accumulator lets a withdrawal remove more assets than its burned raw units cover.

**Why a model gets it wrong:** It treats `mulDiv` as a general precision fix and misses the direction of the final rounding. Likely known in a textbook share example, but the inflated accumulator changes the size of the loss.

**Backing:** zkLend, February 2025, roughly $9.6 million. BlockSec's original transaction and code analysis links flash-loan overpayments, accumulator inflation, and floor-rounded burns: https://blocksec.com/blog/zklend-exploit-post-mortem-unraveling-the-details-and-clarifying-misunderstandings-of-the-10m-flash-loan-attack . Its report dates the incident February 12; other accounts use February 11, so this candidate does not depend on the day.

**Spec source:** BlockSec reproduces the market's scale-down mint and burn logic; the instruction explicitly preserves floor rounding in its proposed full-precision replacement.

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### tokens-tick-crossing-input-threshold
**Instruction:**
Can you approve this proof that a concentrated-liquidity swap cannot cross the next initialized tick? The code computes `amountToReachTick` with one rounded calculation. If the input is smaller, it computes the final square-root price through separately rounded fee-liquidity and price calculations, then skips the tick-crossing liquidity update. The developer claims that `input < amountToReachTick` alone guarantees that the resulting price remains on the original side of the tick. No relation between the rounding errors has been proved. Answer yes or no, then explain in one sentence.

**Answer:** No. The separately rounded final-price calculation can pass the tick even when the input-threshold calculation selects the non-crossing branch.

**Why a model gets it wrong:** It treats the branch decision as a mathematical bound on a different calculation. The names resemble familiar Uniswap logic, which can hide the missing consistency requirement.

**Backing:** KyberSwap Elastic, November 22, 2023. Kyber's first-party report records the `amountSwapToCrossTick - 1` case and the resulting liquidity mismatch: https://blog.kyberswap.com/post-mortem-kyberswap-elastic-exploit/

**Spec source:** The same report's contract-level analysis names `estimateIncrementalLiquidity`, `calcFinalPrice`, and `nextSqrtP > targetSqrtP`.

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### tokens-zero-invariant-reinitialization
**Instruction:**
Does `internalSupply == 0` prove that this pool is safe to initialize again? You are reviewing a liquid-staking-token pool with an internal invariant supply and a separate ERC-20 LP supply. Rate updates can reconcile the two by burning protocol-owned LP tokens, and the internal supply can reach zero while ERC-20 LP balances remain. The original initialization branch becomes callable whenever internal supply is zero. Answer yes or no, then explain in one sentence.

**Answer:** No. A zero internal invariant does not prove that the pool has no prior LP claims or that initialization preconditions still hold.

**Why a model gets it wrong:** It equates the invariant supply with ERC-20 `totalSupply` and treats a zero-supply branch as a harmless first-deposit case.

**Backing:** Yearn yETH, November 30, 2025. Yearn describes internal supply reaching zero while ERC-20 balances remained, followed by re-entry into the initialization branch: https://github.com/yearn/yearn-security/blob/master/disclosures/2025-12-01.md . The requested October date was incorrect.

**Spec source:** Yearn's disclosure, "Phase 3" and "Consolidated root causes", explains the separate supplies and the reachable initialization branch.

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### tokens-double-entry-rescue
**Instruction:**
Does this rescue function preserve the vault's underlying asset balance for every ERC-20 integration? You are reviewing a vault with an arbitrary-token rescue function:
```solidity
require(token != asset);
IERC20(token).transfer(admin, IERC20(token).balanceOf(address(this)));
```
The asset token has a legacy contract address that forwards transfers and balance reads to the same ledger as its current address. `asset` stores only the current address. Answer yes or no, then explain in one sentence.

**Answer:** No. Passing the legacy address bypasses the address comparison and transfers the underlying balance through the shared token ledger.

**Why a model gets it wrong:** It assumes distinct contract addresses identify independent balances. Likely known to auditors who have seen the TUSD disclosure.

**Backing:** ChainSecurity's March 21, 2022 Compound/TUSD disclosure estimated a profitable variant at about $3.1 million: https://www.chainsecurity.com/blog/trueusd---compound-vulnerability/ . TUSD later disabled that secondary address; this instruction specifies a token that still has both.

**Spec source:** The same disclosure explains the two addresses, the shared ledger, and a post-transfer underlying-balance check.

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### tokens-convert-assets-mint-quote
**Instruction:**
Can a router use `convertToAssets(shares)` as the exact maximum asset allowance for `mint(shares, receiver)` across compliant ERC-4626 vaults? You are reviewing a router that makes both calls in one transaction with no intervening state change. Supported vaults can charge entry fees, and the assets needed for a share amount can fall between integer units. Answer yes or no, then explain in one sentence.

**Answer:** No. `convertToAssets` excludes fees and rounds down, while the mint quote includes entry fees and rounds the required assets up.

**Why a model gets it wrong:** It assumes the conversion and preview functions are interchangeable when state does not change. Likely known, so this is a reserve candidate.

**Backing:** Veridise's InceptionLRT audit, March 25, 2025, finding V-IVC-VUL-006, identified the underfunded mint path from floor-rounded `convertToAssets` and its fix through ceiling-rounded `previewMint`: https://veridise.com/wp-content/uploads/2025/11/VAR_inception_250210_smart_contracts_V3.pdf . The finding backs the rounding error; the fee distinction comes from the standard, not that finding.

**Spec source:** ERC-4626's `convertToAssets` and `previewMint` requirements: https://eips.ethereum.org/EIPS/eip-4626 . OpenZeppelin illustrates fee-inclusive `previewMint` and `previewWithdraw`: https://docs.openzeppelin.com/contracts/5.x/erc4626#custom-behavior-adding-fees-to-the-vault

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

### tokens-steth-exact-receipt
**Instruction:**
Can this deposit revert on Ethereum mainnet even when the sender has enough stETH, the allowance is sufficient, and stETH charges no transfer fee? You are reviewing a vault that reads its stETH balance, calls `safeTransferFrom(sender, address(this), amount)`, then requires its balance to have increased by exactly `amount`. Assume no rebase or other transfer occurs during the call. Answer yes or no, then explain in one sentence.

**Answer:** Yes. stETH converts token amounts to shares and back, so rounding can leave the received balance one or two wei below the requested amount.

**Why a model gets it wrong:** It attributes a short receipt only to transfer fees or a rebase. SafeERC20 does not promise an exact balance delta.

**Backing:** Lido's integration guide discloses the one-to-two-wei transfer corner case and describes its effect on Aave V2 exact-amount flows: https://docs.lido.fi/guides/lido-tokens-integration-guide/ . This is a documented integration pitfall; no separate loss incident was verified.

**Spec source:** The same guide's stETH share-accounting and transfer sections; SafeERC20 checks call success and return data, not the receiver's balance delta: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/utils/SafeERC20.sol

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** medium

### tokens-wrapped-staking-unit-reuse
**Instruction:**
Does this adapter invest all the tokens it unwraps? You are reviewing a wstETH adapter that receives `amount` wstETH, calls `wstETH.unwrap(amount)`, and deposits exactly `amount` stETH into a strategy. It ignores the return value of `unwrap`. Assume one wstETH currently unwraps to more than one stETH, no fees apply, and the strategy accepts the deposit. Answer yes or no, then explain in one sentence.

**Answer:** No. The amount uses wstETH units, so reusing it as stETH units leaves some of the unwrapped stETH in the adapter.

**Why a model gets it wrong:** It confuses non-rebasing wrapper balances with a fixed one-to-one conversion. Likely known when the conversion assumption is stated.

**Backing:** Veridise's InceptionLRT audit, March 25, 2025, finding V-IVC-VUL-005, found this exact adapter error and recorded the fix to use `unwrap`'s return value: https://veridise.com/wp-content/uploads/2025/11/VAR_inception_250210_smart_contracts_V3.pdf

**Spec source:** Lido documents wstETH as a non-rebasing balance whose value changes against stETH: https://docs.lido.fi/guides/lido-tokens-integration-guide/

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

## Rejected on the way

- Yearn yETH in October 2025: the date is wrong; Yearn's disclosure records November 30, 2025.
- Yearn solver collapse as a second candidate: verified divergence drove the product term to zero, but a short question became either vague or a numerical puzzle. The first-party disclosure gives the precise sequence: https://github.com/yearn/yearn-security/blob/master/disclosures/2025-12-01.md
- Default-offset multiple-victim profit: the stated OpenZeppelin formula permits a calculated example, but I did not verify a separate primary incident or disclosure for that exact profit variant. Keep the narrower zero-share candidate above.
- Resupply as another Compound v2 empty-market replay: rejected that label. Resupply's own report identifies an ERC-4626 collateral integration and a zero reciprocal that disabled solvency. Sonne is a Compound v2 fork; the mechanisms must remain distinct.
- Hundred Finance as an additional replay: Sonne's Rekt account names the earlier case, but I did not fetch Hundred's first-party analysis within the budget. Do not claim independent verification.
- Fee-on-transfer crediting: the STA/Balancer incident supports it, but crediting the requested transfer amount is textbook. The source catalogue links the incident: https://github.com/d-xo/weird-erc20#fee-on-transfer
- Missing return values: SafeERC20 accepts empty return data from a successful token contract call but rejects a returned false value. That fact is likely known; it also does not normalize fees, rebases, blocklists, or pauses. Pinned source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/utils/SafeERC20.sol
- `forceApprove` versus `safeIncreaseAllowance`: the v5.0.2 implementation already routes `safeIncreaseAllowance` through `forceApprove`. A question that claims callers must always call `forceApprove` directly would be stale. No exact loss incident for this version trap was verified. Same pinned source as above.
- Zero-value transfer reverts: useful compatibility issue, weak frontier discriminator, and no exact loss incident verified here. Do not imply SafeERC20 suppresses the revert. Catalogue: https://github.com/d-xo/weird-erc20
- Blocklists and pausable tokens: denied transfers can block batched payouts, but the yes-or-no question becomes routine denial-of-service reasoning. No fresh exact incident was verified here. Catalogue: https://github.com/d-xo/weird-erc20
- Flash-mintable tokens: total supply can spike without a pre-existing lending balance, but turning this into a hard question needs a named failed denominator or voting integration. The catalogue links Maker's flash-mint module; no qualifying incident was verified: https://github.com/d-xo/weird-erc20#flash-mintable-tokens
- Decimals other than 18: fixed-unit arithmetic and metadata assumptions are familiar. No recent exact incident was verified, so I did not invent one. OpenZeppelin's pinned vault source reads asset decimals and adds the offset rather than promising 18 share decimals: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/extensions/ERC4626.sol
- ERC-777 hooks through the ERC-20 interface: the imBTC/Uniswap and Lendf.me history is real, but the question reduces to familiar callback reentrancy. The catalogue links both incidents: https://github.com/d-xo/weird-erc20#reentrant-calls
- Donation-proof `balanceOf(this)` accounting: direct donations change the live balance and the share rate; treating that alone as a new question is textbook. The virtual-offset collateral-price candidate above asks about the narrower protection claim.
- Fee previews as exact inverses: ERC-4626 requires fees in previews and excludes them from conversions. The useful reserve candidate above also includes the independently disclosed mint-rounding bug. Do not claim a separate fee-preview loss incident was verified.
