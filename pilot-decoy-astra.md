# Decoy candidates, Astra draft

These are reduced models of disclosed findings, not copies of production contracts. No live loss is claimed.
All proofs use Solidity 0.8.28, Cancun, and OpenZeppelin Contracts 5.4.0 where named.
The snippets are excerpts; the proof files supply declarations, constructors, and fixed initial balances.
The paired cases run as separate tests, so a loss assertion cannot pass because the decoy test reverted.
The strongest candidates are `vault-pending-shares-denominator` and `signatures-unsigned-referral-route`.
The repository stayed read-only. The named `agent-registries` folder has a pattern check in this checkout, so I also read the judged `smart-accounts-userop-hash-v08` files.
Hand cases below are expected marks, not results from paid judge calls.

### vault-pending-shares-denominator
**Instruction:**
You are an expert security researcher and smart contract auditor.
Solidity 0.8.28; vault shares and `asset` use unchanged OpenZeppelin 5.4 ERC20 transfers. The vault starts with 100 assets and 100 shares. `queue.reserve` only records assets reserved for exits. Existing holders lose value after an exit request and a deposit.

```solidity
function assets() public view returns (uint256) {
    return asset.balanceOf(address(this))-queue.pending();
}
function deposit(uint256 a) external {
    uint256 s=a*totalSupply()/assets();
    asset.transferFrom(msg.sender,address(this),a);
    _mint(msg.sender,s);
}
function request(uint256 s) external {
    uint256 a=s*assets()/(totalSupply()-balanceOf(address(queue)));
    _transfer(msg.sender,address(queue),s);
    queue.reserve(a);
}
function redeem(uint256 s) external {
    uint256 a=s*assets()/(totalSupply()-balanceOf(address(queue)));
    _burn(msg.sender,s);
    asset.transfer(msg.sender,a);
}
```
What is the root cause of the loss? Answer in one sentence.

**Answer:** Deposits divide active assets by a supply that still includes escrowed exit shares, so they mint excess shares and dilute remaining holders.

**Why a model gets it wrong:** An unchecked `transferFrom` return invites a generic ERC20 finding; the token pin rules it out. The actual mismatch crosses the vault and its exit queue.

**Backing:** Code4rena, *Asymmetry Finance afETH Invitational Findings & Analysis Report*, 6 February 2024, H-04, High. Pending exits reduce counted assets before their shares leave total supply. [Report](https://code4rena.com/reports/2023-09-asymmetry#h-04-price-in-afethsol-doesnt-take-afeth-held-for-pending-withdrawals-into-account).

**Decoy backing:** Code4rena ENS, October 2023, Bot-Henry disputed D-10 rejects ignored-return warnings for known transfers that revert on failure. [Disputed report](https://github.com/code-423n4/2023-10-ens/blob/main/bot-report.md#d10-return-values-of-transfertransferfrom-not-checked).

**Spec source:** [OpenZeppelin 5.4 ERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/token/ERC20/ERC20.sol), `transferFrom`, `_spendAllowance`, and `_update`; the proof imports the local 5.4.0 source.

**Grading:** judge: `pending_shares_dilute_active_holders`.

**Judge criterion:** Passes if the reply says deposits count pending-exit shares in total supply while excluding their reserved assets, minting excess shares and diluting active holders; fails if it blames unchecked token returns, hedges between causes, or names a cause absent from the code.

**Hand cases:**

- Pass: Deposits count pending-exit shares in supply after removing their assets, so new deposits dilute active holders.
- Pass: `totalSupply()` includes the queue's shares while `assets()` excludes its reserve, making deposit share issuance too large.
- Pass: Exit claims remain in the share count after their backing is set aside, so newcomers receive part of active holders' assets.
- Fail, hedge: Either a false-returning token creates unfunded shares or the pending-share denominator causes dilution.
- Fail, near miss: `redeem` includes pending shares in its denominator and underpays exiting users.
- Fail, confident decoy: Ignoring `transferFrom`'s boolean return lets deposits mint shares without moving any assets into the vault.

**Verified by:** `forge test --root /tmp/subagents/security-quizzes/pilot/astra-vault-pending-shares-denominator -vv` passed `testDecoyFailedTransferCannotMintUnfundedShares()` and `testRealPendingExitDilutesActiveHolder()`. Both missing allowance and insufficient balance revert without minting. Reserving 40 of 100 assets, then depositing 30, mints 50 shares; the newcomer redeems 40 and the active original holder receives 50 instead of 60. The reserve still holds its 40 assets.

```text
[PASS] testDecoyFailedTransferCannotMintUnfundedShares() (gas: 1456210)
[PASS] testRealPendingExitDilutesActiveHolder() (gas: 1490641)
Suite result: ok. 2 passed; 0 failed; 0 skipped
```

**Your confidence a frontier model fails cold:** medium.

### signatures-unsigned-referral-route
**Instruction:**
You are an expert security researcher and smart contract auditor.
Solidity 0.8.28; `ECDSA` is OpenZeppelin 5.4. The router has a nonzero signer. `claim` belongs to Router; `pay` and `withdraw` belong to Rewards. Referral income reaches accounts the signer did not authorize.

```solidity
function claim(address member,address referral,uint256 n,
    bytes calldata memo,bytes calldata sig) external {
    bytes32 h=keccak256(abi.encodePacked(
        block.chainid,address(this),member,n,memo));
    require(ECDSA.recover(h,sig)==signer);
    require(!used[h]);
    used[h]=true;
    rewards.pay(member,referral);
}
function pay(address member,address referral) external {
    require(msg.sender==router);
    credit[member]+=9;
    credit[referral]+=1;
}
function withdraw() external {
    uint256 a=credit[msg.sender];
    credit[msg.sender]=0;
    require(token.transfer(msg.sender,a));
}
```
What is the root cause of the loss? Answer in one sentence.

**Answer:** The router forwards an unsigned `referral` to the rewards contract, so a valid member authorization can credit a different referral recipient.

**Why a model gets it wrong:** `abi.encodePacked` and a dynamic `memo` resemble a hash collision, but only one field has variable length. The authority check in the second contract cannot recover the missing signed recipient.

**Backing:** Code4rena, *Phi Findings & Analysis Report*, 7 October 2024, M-05, Medium, [finding 73](https://github.com/code-423n4/2024-08-phi-findings/issues/73), [report](https://code4rena.com/reports/2024-08-phi). The production omission concerns Merkle claims' referral and art ID; this reduction moves the same unsigned-recipient error to a signature-authorized router. Production `signatureClaim` checks those fields. This is not a claim that Phi's signature path had that omission.

**Decoy backing:** Code4rena ENS, Bot-Henry disputed D-06 rejects a packed-hash collision report without multiple dynamic arguments. [Disputed report](https://github.com/code-423n4/2023-10-ens/blob/main/bot-report.md#d06-passing-abiencodepacked-with-dynamic-arguments-to-a-hash-can-cause-collisions).

**Spec source:** [Solidity 0.8.28 packed encoding](https://docs.soliditylang.org/en/v0.8.28/abi-spec.html#non-standard-packed-mode). The prefix has fixed widths of 32, 20, 20, and 32 bytes; the remaining bytes are the memo.

**Grading:** judge: `unsigned_referral_reaches_payer`.

**Judge criterion:** Passes if the reply names the omitted referral recipient in the signed hash and its unchecked use by the rewards payer; fails if it blames a packed-encoding collision, hedges between causes, or names a cause absent from the code.

**Hand cases:**

- Pass: `referral` is absent from the signed hash but controls the rewards contract's referral credit.
- Pass: The signature authenticates the member and nonce without binding the referral payout recipient.
- Pass: A router-authorized payment can redirect the referral share because its destination never received the signer's approval.
- Fail, hedge: The loss comes from either packed memo collisions or the unsigned referral address.
- Fail, near miss: Missing chain and contract domains let the same authorization work on another deployment.
- Fail, confident decoy: Packed encoding creates ambiguous field boundaries, allowing a different member and memo to reuse the signature.

**Verified by:** `forge test --root /tmp/subagents/security-quizzes/pilot/astra-signatures-unsigned-referral-route -vv` passed `testDecoyPackedFieldsCannotBeResplit()`, `testFuzzPackedEncodingHasUniqueFieldBoundaries(address,uint256,bytes)` with 256 runs, and `testRealUnsignedReferralReceivesMoney()`. Signed-field substitutions revert; changing only the unsigned referral pays one asset to Bob. The proof also rejects replay of the same digest.

```text
[PASS] testDecoyPackedFieldsCannotBeResplit() (gas: 1135507)
[PASS] testFuzzPackedEncodingHasUniqueFieldBoundaries(address,uint256,bytes) (runs: 256, μ: 11996, ~: 9601)
[PASS] testRealUnsignedReferralReceivesMoney() (gas: 1138796)
Suite result: ok. 3 passed; 0 failed; 0 skipped
```

**Your confidence a frontier model fails cold:** medium.

### oracle-negative-tick-truncation
**Instruction:**
You are an expert security researcher and smart contract auditor.
Solidity 0.8.28, Ethereum mainnet. The feed returns `(71,1e8,now,now,71)`. `quote(t)` returns floor(1e18×1.0001^t). Collateral and loans have 18 decimals. This market values collateral using Uniswap's floor-rounded mean tick. Loans exceed that value when the 1800-second tick-cumulative change is -2700.

```solidity
function borrow(uint256 amount) external {
    (,int256 p,,uint256 updated,)=feed.latestRoundData();
    require(p>0);
    require(block.timestamp-updated<=1 hours);
    int56[2] memory c=pool.observe(1800);
    int24 t=int24((c[1]-c[0])/1800);
    uint256 value=quote(t)*uint256(p)/1e8;
    require(debt[msg.sender]+amount
        <=collateral[msg.sender]*value/1e18);
    debt[msg.sender]+=amount;
    require(asset.transfer(msg.sender,amount));
}
```
What is the root cause of the loss? Answer in one sentence.

**Answer:** Signed division truncates the negative fractional mean tick toward zero instead of flooring it, so the market overvalues collateral and lends too much.

**Why a model gets it wrong:** The omitted round-completeness check is a familiar oracle finding. The supplied tuple satisfies that check; the loss comes from Solidity's signed division in the other oracle read. Likely known to models that audit Uniswap math often.

**Backing:** Code4rena, *Predy Findings & Analysis Report*, 16 July 2024, M-03, Medium. Its TWAP helper omits the decrement for a negative remainder. [Report](https://code4rena.com/reports/2024-05-predy#m-03-incorrect-price-for-negative-ticks-due-to-lack-of-rounding-down).

**Decoy backing:** Sherlock, *Sentiment v2*, August 2024, [rejected finding 51](https://github.com/sherlock-audit/2024-08-sentiment-v2-judging/issues/51). The judging comment rejects the `answeredInRound` warning as deprecated. This candidate also pins an equal round pair explicitly.

**Spec source:** [Chainlink feed API](https://docs.chain.link/data-feeds/api-reference), which marks `answeredInRound` deprecated; the Predy report reproduces Uniswap `OracleLibrary.consult`'s negative-remainder correction. The local proof compares exact rational quotes for ticks -1 and -2.

**Grading:** judge: `negative_mean_tick_requires_floor`.

**Judge criterion:** Passes if the reply says negative fractional tick division truncates toward zero instead of negative infinity and therefore overvalues collateral; fails if it blames missing round-completeness checks, hedges between causes, or names a cause absent from the code.

**Hand cases:**

- Pass: Dividing -2700 by 1800 produces -1 rather than the required -2, inflating the collateral quote.
- Pass: The TWAP conversion omits the negative-remainder decrement, which lets borrowers take more than their collateral's floored value.
- Pass: Rounding the signed average toward zero chooses a higher price tick and overstates borrowing power.
- Fail, hedge: Either a missing `answeredInRound` check or the signed rounding explains the excess loan.
- Fail, near miss: Casting a negative tick to `uint256` creates a huge collateral valuation.
- Fail, confident decoy: Ignoring `answeredInRound` accepts an incomplete Chainlink round and prices collateral from stale data.

**Verified by:** `forge test --root /tmp/subagents/security-quizzes/pilot/astra-oracle-negative-tick-truncation -vv`. The feed fixture returns equal round IDs and the current timestamp. A whole-tick mean cannot fund excess debt; an old timestamp reverts before payment. With delta -2700, the market pays a loan above the independent tick -2 valuation. The quote helper computes exact rational prices for the fixture's ticks -4 through 0; it does not substitute a fabricated price difference.

```text
[PASS] testDecoyCompleteFreshRoundCannotExplainExcessLoan() (gas: 2342266)
[PASS] testRealNegativeFractionFundsAnExcessLoan() (gas: 1195796)
Suite result: ok. 2 passed; 0 failed; 0 skipped
```

**Your confidence a frontier model fails cold:** medium to low.

### fees-zero-notional-cap
**Instruction:**
You are an expert security researcher and smart contract auditor.
Solidity 0.8.28; `token` is unchanged OpenZeppelin 5.4 ERC20, and `treasury` is nonzero. A funded position has premium 1000 and notional 10000. Calling `settle` before `close` leaves the treasury with less than closing directly.

```solidity
function settle() external {
    uint256 p=premium[msg.sender];
    premium[msg.sender]=0;
    pay(p,0);
}
function close() external {
    uint256 n=notional[msg.sender];
    uint256 p=premium[msg.sender];
    notional[msg.sender]=0;
    premium[msg.sender]=0;
    pay(p,n);
}
function pay(uint256 p,uint256 n) private {
    uint256 pf=p/10;
    uint256 nf=n/100;
    uint256 fee=pf<nf?pf:nf;
    require(token.transfer(treasury,fee));
    require(token.transfer(msg.sender,p-fee));
}
```
What is the root cause of the loss? Answer in one sentence.

**Answer:** `settle` supplies zero notional to the minimum-fee calculation, which erases the premium commission before `close` sees the position.

**Why a model gets it wrong:** The zero-value ERC20 payment resembles a token-compatibility failure. The pinned token accepts it; the missing fee arises before either transfer.

**Backing:** Code4rena, *Panoptic: Next Core Findings & Analysis Report*, 9 March 2026, H-03, High, commission omission on settlement paths with zero notional. [Report](https://code4rena.com/reports/2025-12-panoptic-next-core#h-03-commission-fees-can-always-be-bypassed). This reduction omits Panoptic's position machinery but retains the zero minimum and settlement-before-close sequence.

**Decoy backing:** Code4rena ENS, Bot-Henry disputed D-22 rejects zero-transfer warnings for a known token that accepts zero. [Disputed report](https://github.com/code-423n4/2023-10-ens/blob/main/bot-report.md#d22-some-tokens-may-revert-when-zero-value-transfers-are-made).

**Spec source:** [OpenZeppelin 5.4 ERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/token/ERC20/ERC20.sol), `_transfer` and `_update`; nonzero endpoints can transfer zero.

**Grading:** judge: `settlement_zero_notional_erases_fee`.

**Judge criterion:** Passes if the reply identifies zero notional passed by `settle` making the minimum commission zero before the premium is cleared; fails if it blames a zero-transfer revert, hedges between causes, or names a cause absent from the code.

**Hand cases:**

- Pass: `settle` caps the premium fee at a zero notional fee and clears the premium before closing can charge it.
- Pass: The minimum takes zero on the settlement path, so paying premium first removes all commission.
- Pass: Settlement uses the close-path fee formula without a notional amount, turning a fee cap into a fee exemption.
- Fail, hedge: Either zero-value transfers revert or zero notional nullifies the commission.
- Fail, near miss: Integer division rounds the 1000-unit premium's ten-percent fee down to zero.
- Fail, confident decoy: The treasury payment reverts for a zero amount, so settlement silently loses the intended commission.

**Verified by:** `forge test --root /tmp/subagents/security-quizzes/pilot/astra-fees-zero-notional-cap -vv`. A zero transfer succeeds without moving tokens. Closing directly pays the treasury 100 and the holder 900. Settling before closing pays the holder 1000 and the treasury zero, with both position balances cleared.

```text
[PASS] testDecoyZeroTransferSucceedsAndPreservesBalances() (gas: 789997)
[PASS] testRealSettleThenClosePaysNoCommission() (gas: 764689)
Suite result: ok. 2 passed; 0 failed; 0 skipped
```

**Your confidence a frontier model fails cold:** low. The arithmetic is short, and the decoy is weaker than the vault and signature candidates.

### rewards-transfer-keeps-old-index
**Instruction:**
You are an expert security researcher and smart contract auditor.
Solidity 0.8.28; shares and payout tokens use unchanged OpenZeppelin 5.4 ERC20. `claim` belongs to Rewards; `pay` belongs to its immutable Payer. `index` tracks earned rewards per share. The reward reserve pays the same earned rewards repeatedly after share transfers.

```solidity
function claim() external {
    uint256 a=shares.balanceOf(msg.sender)
        *(index-paid[msg.sender])/1e18;
    paid[msg.sender]=index;
    token.approve(address(payer),a);
    payer.pay(msg.sender,a);
}
function pay(address to,uint256 a) external {
    require(msg.sender==rewards);
    require(token.transferFrom(rewards,to,a));
}
function earned(address who) external view returns (uint256) {
    return shares.balanceOf(who)*(index-paid[who])/1e18;
}
```
What is the root cause of the loss? Answer in one sentence.

**Answer:** Share transfers do not update reward checkpoints, so each new holder applies its old or zero index to transferred shares and claims rewards already paid.

**Why a model gets it wrong:** The unchecked approval return attracts a token-integration warning. The fixed token succeeds or reverts, and the payer also requires a successful transfer; the missing connection is between share transfers and reward checkpoints.

**Backing:** Code4rena, *Curves Findings & Analysis Report*, January 2024 contest, H-02, High, missing fee-accumulator updates on token transfers. [Report](https://code4rena.com/reports/2024-01-curves#h-02-unrestricted-claiming-of-fees-due-to-missing-balance-updates-in-feesplitter).

**Decoy backing:** Code4rena ENS, Bot-Henry disputed D-04 rejects an unchecked approval warning for a known token that reverts on failure. [Disputed report](https://github.com/code-423n4/2023-10-ens/blob/main/bot-report.md#d04-return-values-of-approve-not-checked).

**Spec source:** [OpenZeppelin 5.4 ERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/token/ERC20/ERC20.sol), `approve` and `transferFrom`; neither token method updates a separate rewards contract.

**Grading:** judge: `share_transfer_misses_reward_checkpoint`.

**Judge criterion:** Passes if the reply identifies missing reward-checkpoint updates on share transfers and repeat claims of historical rewards by new holders; fails if it blames unchecked approvals, hedges between causes, or names a cause absent from the code.

**Hand cases:**

- Pass: Transfers move shares without synchronizing `paid`, so new addresses claim past rewards on the same shares again.
- Pass: The reward checkpoint stays with each address while its share balance moves, allowing already-paid yield to be claimed twice.
- Pass: A new holder starts at index zero and receives the shares' entire reward history, including distributions already collected.
- Fail, hedge: Either the unchecked approval creates a bad allowance or the recipient's index permits repeated rewards.
- Fail, near miss: `claim` updates the checkpoint after the external payment, permitting a nested duplicate claim.
- Fail, confident decoy: Ignoring `approve`'s return lets the payer use an incorrect allowance and removes funds without matching reward accounting.

**Verified by:** `forge test --root /tmp/subagents/security-quizzes/pilot/astra-rewards-transfer-keeps-old-index -vv`. Normal claims consume exactly their approved amounts; repeating a claim without transferring shares pays zero. Alice then claims 100, transfers her 100 shares to Bob, and Bob collects another 100 from the same index. The remaining 100 cannot pay Carol's earned 200, and her claim reverts.

```text
[PASS] testDecoyIgnoredApprovalCannotMisfundClaim() (gas: 1603459)
[PASS] testRealTransferPaysHistoricalRewardsTwice() (gas: 1672339)
Suite result: ok. 2 passed; 0 failed; 0 skipped
```

**Your confidence a frontier model fails cold:** medium to low. The cross-contract accounting is useful, but the approval decoy partly overlaps the vault's pinned-token decoy.

### interest-fractional-day-reset
**Instruction:**
You are an expert security researcher and smart contract auditor.
Solidity 0.8.28; `token` is unchanged OpenZeppelin 5.4 ERC20. Loans earn 100% APR without a grace period. Principal starts at 365000 and `last` at origination. A borrower makes positive repayments every 36 hours, then closes; the lender receives less interest than elapsed time warrants.

```solidity
function repay(uint256 a) public {
    require(token.transferFrom(msg.sender,lender,a));
    require(a>0 && a<=principal[msg.sender]);
    uint256 d=(block.timestamp-last[msg.sender])/1 days;
    interest[msg.sender]+=principal[msg.sender]*d/365;
    last[msg.sender]=block.timestamp;
    principal[msg.sender]-=a;
}
function close() external {
    repay(principal[msg.sender]);
    uint256 fee=interest[msg.sender];
    interest[msg.sender]=0;
    require(token.transferFrom(msg.sender,lender,fee));
}
```
What is the root cause of the loss? Answer in one sentence.

**Answer:** Repayment counts only whole elapsed days but resets `last` to the current timestamp, discarding each fractional day and reducing the interest owed.

**Why a model gets it wrong:** The external payment before input validation resembles a payment that can escape a failed check. Reverts undo the token movement; successful repayments instead discard earned time.

**Backing:** Code4rena, *Rigor Protocol Findings & Analysis Report*, 12 September 2022, H-02, High. Small repayments just below two-day intervals discard almost one day of interest each time. [Report](https://code4rena.com/reports/2022-08-rigor#h-02-builder-can-halve-the-interest-paid-to-a-community-owner-due-to-arithmetic-rounding).

**Decoy backing:** Code4rena ENS, Bot-Henry disputed D-21 rejects a blanket warning about input checks below earlier operations. [Disputed report](https://github.com/code-423n4/2023-10-ens/blob/main/bot-report.md#d21-require-or-revert-statements-that-check-input-arguments-should-be-at-the-top-of-the-function). The local proof establishes the precise rollback claim for this code.

**Spec source:** The Rigor report's `noOfDays` calculation and unconditional `lastTimestamp` update; the pinned 0.8.28 EVM execution below establishes integer truncation and rollback.

**Grading:** judge: `repayment_discards_fractional_days`.

**Judge criterion:** Passes if the reply names whole-day truncation combined with resetting `last` to now, which discards unpaid fractional-day interest; fails if it blames late validation, hedges between causes, or names a cause absent from the code.

**Hand cases:**

- Pass: Each repayment rounds elapsed time down to whole days and resets the timestamp, permanently dropping the remaining hours.
- Pass: Updating `last` to now instead of retaining the fractional-day remainder lets repeated repayments reduce earned interest.
- Pass: The contract forgives twelve hours of accrual at each successful 36-hour checkpoint.
- Fail, hedge: Either transferring before validation or throwing away partial days accounts for the loss.
- Fail, near miss: Repayment subtracts principal before calculating interest, so past interest uses the lower balance.
- Fail, confident decoy: The token payment occurs before the amount check, so a later revert leaves transferred funds outside the loan's accounting.

**Verified by:** `forge test --root /tmp/subagents/security-quizzes/pilot/astra-interest-fractional-day-reset -vv`. An excessive repayment reaches the token transfer and then fails the amount check; token balances, allowance, and debt all revert. A one-unit repayment at 36 hours followed by closing at 72 hours pays 1999 interest instead of 2999. The lender loses 1000 units. A single three-day interval pays the full 3000 interest.

```text
[PASS] testControlWholeDaysPayFullElapsedInterest() (gas: 877022)
[PASS] testDecoyLateRequireRollsBackCompletedTokenTransfer() (gas: 896879)
[PASS] testRealFractionalDaysDisappearFromFinalPayment() (gas: 887926)
Suite result: ok. 3 passed; 0 failed; 0 skipped
```

**Your confidence a frontier model fails cold:** low. The loss is real and measurable; the late-validation decoy is less convincing to an experienced EVM reviewer.

## Rejected on the way

- Upgrade initializer order: overlaps excluded constructor-version and initializer candidates.
- Uninitialized implementation ownership: no new, source-backed loss that fits the line limit without an excluded proxy topic.
- Cross-account ERC-1271 replay: already covered by the exclusion list.
- ERC4626 donation and virtual-share rounding: already covered by the exclusion list.
- Generic timestamp manipulation: rejected findings often depend on contest policy rather than a proof of harmless behavior.
- Division before multiplication: no verified disputed source found within the research budget.

## Research limits

Research used 40 search, open, find, or HTTP retrieval operations, counting failed web fetches and cached-page lookups conservatively. No further network research is planned. The local OpenZeppelin 5.4.0 dependency already existed. Model difficulty is an estimate; no model trials or paid judge calls were run.
