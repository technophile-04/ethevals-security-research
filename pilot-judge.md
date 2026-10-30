# Published findings for judge-graded security questions

Six candidates follow. Each proof concerns a reduced Solidity model, not the complete audited protocol. No model trials or judge calls have run.

All six have local Foundry proofs, with 17 passing checks and no failures. None relies only on a cited line. Source research used 43 fetches or searches, including failed requests, within the limit of 45. Foundry ran offline with the cached compiler.

The two strongest candidates are `options-position-fingerprint-wrap` and `lending-repayment-borrower-changes`. The emission calculation ranks next. The other three have verified causes but lower confidence that a frontier model answers incorrectly.

The cited agent-registries task is currently a pattern-graded ERC-number question and has no hand cases. The criteria below follow ADR 0016 instead. Each criterion grades only the final reply.

### options-position-fingerprint-wrap
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28. `stored` is the trusted commitment to the account's actual positions; `margin[id]` is premium minus required collateral.

```solidity
function healthy(uint256[] calldata ids)
    external view returns (bool) {
    uint8 count;
    uint248 fingerprint;
    int256 net = -120;
    unchecked {
        for (uint256 i; i < ids.length; ++i) {
            ++count;
            fingerprint ^= uint248(uint256(keccak256(abi.encode(ids[i]))));
            net += margin[ids[i]];
        }
    }
    require(bytes32((uint256(count) << 248) | fingerprint) == stored);
    return net >= 0;
}
```

An insolvent account passes after its list grows. What root cause must the reviewer flag?
Answer in one sentence.

**Answer:** Adding 256 copies of a profitable position cancels their XOR hashes and wraps the byte count, preserving the commitment while counting that position's positive margin repeatedly.

**Why a model gets it wrong:** The length byte appears to repair XOR's duplicate cancellation. The reader must connect its wraparound to the later accounting. Likely known to models trained on this finding.

**Backing:** Code4rena, *Panoptic Findings & Analysis Report*, published 24 June 2024, M-02, **Medium**. [Report](https://code4rena.com/reports/2024-04-panoptic), [finding #498](https://github.com/code-423n4/2024-04-panoptic-findings/issues/498). The disclosure shows repeated IDs passing validation and explains the resulting solvency error. It reports no live loss.

**Spec source:** [PanopticMath.updatePositionsHash and the accounting path in finding #498](https://github.com/code-423n4/2024-04-panoptic-findings/issues/498). The reduced model keeps the original 8-bit count and 248-bit XOR. `net = -120` represents other fixed liabilities. The caller supplies the list; `stored` comes from trusted account state.

**Grading:** judge: criterion `repeated_positions_preserve_commitment`

**Judge criterion:** Passes if the reply says 256 repeated position IDs cancel in XOR and wrap the 8-bit count, preserving the commitment while inflating margin through repeated entries; fails otherwise, including hedges or a different cause.

**Hand cases:**
- pass: "Adding 256 copies cancels their XOR and wraps the count, so the same commitment accepts repeatedly counted positive margin."
- pass: "The byte count wraps after 256 duplicates while XOR cancels them, letting one profitable position inflate the solvency sum."
- pass: "A whole cycle of repeated entries leaves both parts of the fingerprint unchanged but counts the same premium surplus again."
- fail, hedge: "Either repeated entries wrap the count and cancel in XOR, or signed net overflow makes the account solvent."
- fail, near miss: "Any two duplicates leave the entire commitment unchanged because XOR cancels them."
- fail, wrong: "Keccak collisions let two different position IDs share the same premium balance."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/options-position-fingerprint-wrap` passes 3 checks with solc 0.8.28, optimizer 200, legacy pipeline, Cancun. `test256CopiesPreserveCommitmentAndInflateMargin` accepts the repeated list; `testActualPositionsAreInsolvent` rejects the real account economically; `testTwoCopiesFailCountCheck` proves XOR cancellation alone is insufficient. The trusted commitment contains two positions. Their true net is -130, while 256 added copies raise the sum to 2430.

**Your confidence a frontier model fails cold:** medium

### lending-repayment-borrower-changes
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28. Anyone can repay for another account. A keeper replaces an unhealthy borrower without changing the loan ID or amount.

```solidity
struct Loan { address borrower; uint256 due; bool paid; }
mapping(uint256 => Loan) public loans;
function replace(uint256 id, address next) external onlyKeeper {
    _liquidate(loans[id].borrower, loans[id].due);
    loans[id].borrower = next;
    _fund(next);
}
function repay(uint256 id) external {
    Loan storage loan = loans[id];
    require(!loan.paid);
    cash.transferFrom(msg.sender, address(this), loan.due);
    _closeDebt(loan.borrower, loan.due);
    loan.paid = true;
}
```

A borrower loses collateral, then pays cash despite submitting repayment first. What root cause must the reviewer flag?
Answer in one sentence.

**Answer:** Repayment binds only the loan ID, so a keeper's earlier replacement changes its borrower and the pending repayment pays the new borrower's debt after liquidation already charged the old borrower.

**Why a model gets it wrong:** Permission to repay for someone else is intentional. The defect is that the transaction cannot constrain which borrower the mutable ID names when it executes.

**Backing:** Code4rena, *Size Findings & Analysis Report*, published 16 September 2024, H-02, **High**. [Report](https://code4rena.com/reports/2024-06-size), [finding #181](https://github.com/code-423n4/2024-06-size-findings/issues/181). The finding describes an honest keeper executing before a pending repayment and the old borrower paying twice. It reports no live loss.

**Spec source:** [Repay.sol at 8850e25](https://github.com/code-423n4/2024-06-size/blob/8850e25fb088898e9cf86f9be1c401ad155bea86/src/libraries/actions/Repay.sol), especially `RepayParams` and `executeRepay`; [replacement and proposed expected-borrower check](https://github.com/code-423n4/2024-06-size-findings/issues/181). The model leaves liquidity-index accounting out and preserves loan identity and payment order.

**Grading:** judge: criterion `repayment_does_not_bind_expected_borrower`

**Judge criterion:** Passes if the reply says a replacement can change the borrower behind the same loan ID before repayment executes, so the already-liquidated borrower pays the replacement borrower's debt because repayment does not bind the expected borrower; fails otherwise, including hedges or a different cause.

**Hand cases:**
- pass: "Repay names only a mutable loan ID, so an earlier replacement makes the liquidated borrower's pending payment settle the successor's debt."
- pass: "The transaction lacks an expected-borrower check, so keeper ordering charges the old borrower collateral and then cash for the new borrower."
- pass: "The ID survives reassignment, but the payer cannot require that it still names their debt when the transaction lands."
- fail, hedge: "Either reassignment changes whose debt gets paid, or the keeper reenters repayment during liquidation."
- fail, near miss: "Repayment must reject all callers other than the current borrower because paying for another account is forbidden."
- fail, wrong: "The EVM executes the transaction submitted first, so only an invalid keeper signature can explain the loss."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/lending-repayment-borrower-changes` passes 2 checks with solc 0.8.28, optimizer 200, legacy pipeline, Cancun. `testReplacementThenPendingRepaymentChargesOldBorrowerTwice` reduces old collateral from 150 to 45 and old cash from 100 to zero; the successor keeps 90 cash and has zero debt. `testRepayBeforeReplacementPaysOriginalDebt` leaves collateral at 150. The fixture models execution order, not mempool timing, and uses a checked allowance and balance ledger.

**Your confidence a frontier model fails cold:** medium

### bridge-holder-flag-freezes-local-balance
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28. On this chain, locally issued tokens must remain transferable during the bridge lock. Authenticated bridge messages can name any recipient.

```solidity
mapping(address => bool) public imported;
function credit(address recipient, uint256 amount) external onlyBridge {
    _mint(recipient, amount);
    imported[recipient] = true;
}
function transfer(address to, uint256 amount) external returns (bool) {
    if (locked && imported[msg.sender] && to != staking)
        revert Restricted();
    _transfer(msg.sender, to, amount);
    return true;
}
```

A holder's locally issued balance stops moving after an unsolicited bridge credit. What root cause must the reviewer flag?
Answer in one sentence.

**Answer:** A recipient-wide boolean treats every token as imported after any bridge credit, so a small unsolicited credit restricts the holder's entire locally issued balance.

**Why a model gets it wrong:** The authenticated bridge and intended restrictions appear to justify the flag. Authentication does not establish that the recipient chose to import tokens. Likely known; the code is short.

**Backing:** Code4rena, *THORWallet Findings & Analysis Report*, published 15 April 2025, M-1, **Medium**. [Report, M-1](https://code4rena.com/reports/2025-02-thorwallet). The finding concerns ordinary balances on Base, outside the Arbitrum-wide lock. The judge records loss of transfer access rather than direct asset loss.

**Spec source:** [Titn.sol at 98d7e936](https://github.com/code-423n4/2025-02-thorwallet/blob/98d7e936518ebd80e2029d782ffe763a3732a792/contracts/Titn.sol#L77-L112). `_credit` marks the whole recipient; `_validateTransfer` does not distinguish token amounts by origin. The model keeps the staking exception and omits owner and endpoint exceptions. The report says the subsequent self-recipient bridge restriction prevents this unsolicited-credit route.

**Grading:** judge: criterion `bridge_flag_restricts_unrelated_balance`

**Judge criterion:** Passes if the reply says any unsolicited bridge credit sets an account-wide imported flag that restricts the recipient's pre-existing locally issued balance instead of only the imported amount; fails otherwise, including hedges or a different cause.

**Hand cases:**
- pass: "Any bridge credit sets imported for the whole recipient, so a tiny unsolicited receipt locks their pre-existing local tokens too."
- pass: "The flag tracks whether an address ever received imported tokens, rather than how much of its balance is restricted."
- pass: "The code assigns one restriction to a mixed balance, allowing another sender's receipt to freeze unrelated local holdings."
- fail, hedge: "Either the account flag freezes unrelated tokens, or unauthenticated callers can invoke credit directly."
- fail, near miss: "The bridge lock must reject transfers into staking as well as ordinary transfers."
- fail, wrong: "Minting imported tokens overwrites the holder's local balance with the credited amount."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/bridge-holder-flag-freezes-local-balance` passes 3 checks with solc 0.8.28, optimizer 200, legacy pipeline, Cancun. `testUnsolicitedCreditRestrictsLocalBalance` proves a credit of 1 blocks transfer of the existing 1000. `testLocalBalanceTransfersBeforeCredit` proves the same transfer works before credit. `testSendingImportedAmountToStakingDoesNotClearFlag` proves the local 1000 remain restricted after forwarding the credited 1 to staking. The fixture represents an authenticated destination bridge call, not the complete cross-chain transport.

**Your confidence a frontier model fails cold:** low

### emissions-burned-principal-subtracted-twice
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28. Creating a permanent position burns its principal; `burnedPrincipal()` records those destroyed tokens. The reward uses circulating tokens outside the locker.

```solidity
function rebase(uint256 issuance) external view returns (uint256) {
    uint256 supply = token.totalSupply();
    uint256 escrow = token.balanceOf(locker);
    uint256 retired = locks.burnedPrincipal();
    uint256 bonus = locks.bonus(retired);
    uint256 effectiveSupply = supply + bonus;
    uint256 locked = escrow + retired + bonus;
    uint256 circulating = effectiveSupply - locked;
    return (issuance * circulating / effectiveSupply)
        * circulating / (2 * effectiveSupply);
}
```

Rewards underpay even with exact divisions. What root cause must the reviewer flag?
Answer in one sentence.

**Answer:** `totalSupply()` already excludes burned principal, but subtracting `locked` removes that principal again, understating circulating supply and therefore the reward.

**Why a model gets it wrong:** Adding burned principal to the effective locked supply looks consistent with permanent voting positions. The reader must track which supply still contains those tokens.

**Backing:** Code4rena, *Blackhole Findings & Analysis Report*, published 3 July 2025, M-01, **Medium**. [Report, M-01](https://code4rena.com/reports/2025-05-blackhole). The finding describes rebase underpayment and excess allocation to gauges. Use the report's final Medium rating; the submission body argues for High. No live loss is claimed.

**Spec source:** [MinterUpgradeable.calculate_rebase at 92fff849](https://github.com/code-423n4/2025-05-blackhole/blob/92fff849d3b266e609e6d63478c4164d9f608e91/contracts/MinterUpgradeable.sol#L124-L136). [The report's proposed calculation](https://code4rena.com/reports/2025-05-blackhole) sets circulating supply to current total supply minus escrow, because permanent-position principal has already burned. The model retains bonus cancellation in the numerator. The report marks M-01 mitigated.

**Grading:** judge: criterion `burned_principal_reduces_circulation_twice`

**Judge criterion:** Passes if the reply says totalSupply already excludes burned permanent-position principal and subtracting retired principal again understates circulating supply and the rebase; fails otherwise, including hedges or a different cause.

**Hand cases:**
- pass: "Burned principal has already reduced totalSupply, so including it in locked subtracts it again and underpays the rebase."
- pass: "Circulating becomes supply minus escrow minus retired, although retired tokens no longer exist in supply."
- pass: "The numerator removes the same retired tokens twice, reducing the circulation ratio and its squared reward."
- fail, hedge: "Either retired principal gets subtracted twice, or early integer division alone explains the shortfall."
- fail, near miss: "Bonus appears twice in circulating and therefore lowers the numerator by twice the bonus."
- fail, wrong: "Permanent locks keep their principal in totalSupply, so subtracting retired correctly measures circulating tokens."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/emissions-burned-principal-subtracted-twice` passes 2 checks with solc 0.8.28, optimizer 200, legacy pipeline, Cancun. `testBurnedPrincipalUnderpaysWithoutRounding` uses current supply 900, escrow 100, burned principal 200, bonus zero and issuance 16200. The snippet pays 3600 instead of 6400, with both faulty divisions exact. `testNoBurnedPrincipalMatchesCirculatingSupply` pays the intended 6400 when retired principal is zero.

**Your confidence a frontier model fails cold:** medium

### tokens-whitelisted-burn-short-circuit
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28. Both roles can coexist. In restricted mode, blocked holders must retain balances for administrative recovery.

```solidity
function permitted(address from, address to) internal view returns (bool) {
    if (minter[msg.sender] && !blocked[from] && to == address(0))
        return true;
    if (listed[msg.sender] && listed[from] && to == address(0))
        return true;
    return listed[msg.sender] && listed[from] && listed[to]
        && !blocked[msg.sender] && !blocked[from] && !blocked[to];
}
function burn(uint256 amount) external {
    require(permitted(msg.sender, address(0)));
    _burn(msg.sender, amount);
}
```

A blocked holder destroys the balance before recovery. What root cause must the reviewer flag?
Answer in one sentence.

**Answer:** A holder who remains listed reaches the burn branch's early success without a blocked-role check, so the later blocked checks never protect that burn.

**Why a model gets it wrong:** The surrounding transfer policy checks blocked status, but its exception branches have separate conditions. Likely known; a careful reader can spot the early return.

**Backing:** Code4rena, *Ethena Labs Invitational Findings & Analysis Report*, published 2 December 2024, M-01, **Medium**. [Report](https://code4rena.com/reports/2024-11-ethena-labs), [finding #15](https://github.com/code-423n4/2024-11-ethena-labs-findings/issues/15). A holder with both roles can burn before the administrator redistributes the balance. The disclosure claims no live loss or collateral redemption through this path.

**Spec source:** [UStb._beforeTokenTransfer, audited code](https://github.com/code-423n4/2024-11-ethena-labs/blob/main/contracts/ustb/UStb.sol). In `WHITELIST_ENABLED`, the whitelisted burn branch omits blacklist checks that later normal-transfer conditions include. The reduced model omits administrator and issuance branches. Unlike the report's M-02, this question concerns a holder's own public burn, not minter-led redemption.

**Grading:** judge: criterion `listed_burn_omits_blocked_check`

**Judge criterion:** Passes if the reply says the holder can retain both roles and the listed-holder burn branch succeeds without checking blocked status before the later blocked checks run; fails otherwise, including hedges or a different cause.

**Hand cases:**
- pass: "A holder can be both listed and blocked, and the listed burn branch returns true before any blocked check applies."
- pass: "The burn exception checks listing but omits blocking, so later normal-transfer restrictions never stop a dual-role holder's burn."
- pass: "The early destruction permission ignores the adverse role even when both roles remain assigned."
- fail, hedge: "Either the listed burn branch ignores blocking, or the minter role gives the holder permission to burn anyone's funds."
- fail, near miss: "An unlisted holder redeems through the minter branch without a listing check."
- fail, wrong: "The final return's blocked checks run after every true return, so only integer overflow explains the lost balance."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/tokens-whitelisted-burn-short-circuit` passes 4 checks with solc 0.8.28, optimizer 200, legacy pipeline, Cancun. `testListedBlockedHolderBurnsEntireRecoverableBalance` reduces the dual-role holder's 100 to zero. Controls reject an unlisted blocked holder's burn, allow a listed unblocked holder's burn, and reject the dual-role holder's ordinary transfer. No collateral redemption is modelled or claimed.

**Your confidence a frontier model fails cold:** low

### swaps-direction-ignores-pool-token-order
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28. The router's high bit means token1 is input; zero means token0 is input. The pool sorts tokens by address.

```solidity
uint256 constant REVERSE = 1 << 255;
function route(address input, address output, uint256 amount)
    external view returns (uint256 descriptor, uint256 expected) {
    require(input == wrapped || output == wrapped);
    expected = quoter.quote(pool, input, output, amount);
    uint256 direction;
    if (input == wrapped) {
        direction = REVERSE;
    }
    descriptor = uint256(uint160(pool)) | direction;
}
```

Quotes work, but execution fails for some deployments. What root cause must the reviewer flag?
Answer in one sentence.

**Answer:** The direction flag assumes the wrapped token is always token1, so pools where it is token0 encode the opposite input direction despite a correct token-address quote.

**Why a model gets it wrong:** The quote explicitly names both tokens and can appear to establish the execution direction. The router consumes only the encoded pool and flag. Likely known; token ordering is common knowledge.

**Backing:** Code4rena, *Lambo.win Findings & Analysis Report*, published 3 February 2025, H-03, **High**. [Report, H-03](https://code4rena.com/reports/2024-12-lambowin). The finding concerns `_getQuoteAndDirection` assuming a fixed WETH pool position. The report describes incorrect routing and potential loss, not a published live loss.

**Spec source:** [LamboRebalanceOnUniwap.sol, constants, router descriptor and quote helper](https://github.com/code-423n4/2024-12-lambowin/blob/main/src/rebalance/LamboRebalanceOnUniwap.sol). `_BUY_MASK` sets bit 255 and `_getQuoteAndDirection` chooses it by `tokenIn == weth`. The question supplies the router's flag convention explicitly; its proof implements that convention without external router dependencies.

**Grading:** judge: criterion `direction_uses_asset_identity_instead_of_pool_order`

**Judge criterion:** Passes if the reply says the flag assumes wrapped is token1 and reverses the actual input direction when wrapped is token0, while a quote by token addresses does not fix that flag; fails otherwise, including hedges or a different cause.

**Hand cases:**
- pass: "The flag hardcodes wrapped as token1, so wrapped-as-token0 pools execute in the opposite direction despite a correct quote."
- pass: "A token-address quote does not determine the router's token-index bit, which must follow actual pool order rather than wrapped-token identity."
- pass: "Deployment address ordering changes the meaning of the input index, but the encoded direction never checks that order."
- fail, hedge: "Either the direction bit assumes the wrong token order, or the view quoter mutates the pool price."
- fail, near miss: "The high bit overwrites the pool address, so the router calls a different contract."
- fail, wrong: "Uniswap always sorts wrapped native currency into token1, so the direction flag is correct for every deployment."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/swaps-direction-ignores-pool-token-order` passes 3 checks with solc 0.8.28, optimizer 200, legacy pipeline, Cancun. `testWrappedAsToken0QuotesCorrectlyButEncodesWrongInput` returns the correct quote but decodes the other token as input, while preserving the pool address. The opposite input also fails for that ordering; a wrapped-as-token1 control encodes the correct input. The router fixture decodes the supplied flag convention. It does not execute a swap or prove a particular monetary loss.

**Your confidence a frontier model fails cold:** low

## Rejected on the way

`build-judge-proofs.py` regenerates all six local proofs from the exact code blocks above through `apply_patch`. Each proof adds only the surrounding state and dependencies needed to compile the snippet. The proof folders include their pinned Foundry settings.

- The previous five-candidate draft relied mainly on incident write-ups without a published severity. It is preserved in `pilot-judge.previous.md`.
- Next Generation M-01, fee charged beyond allowance, has a clear cause but the sponsor deferred its fix with fees disabled.
- Blackhole's governor findings concern a component the sponsor chose not to deploy. The emission calculation has a clearer product effect.
- Lambo.win H-02, pre-created pairs blocking deployment, is a familiar deployment-order problem with a disputed proposed fix.
- Compiler and ERC-2771 topics in `pilot-opus.md` overlap the excluded list and were not reused.
