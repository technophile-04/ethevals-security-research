# Multi-issue candidates

All snippets pin Solidity 0.8.28. Severities below are the published findings' ratings, not new ratings for these reductions.
The judge accepts harmless style or gas notes. Any additional false vulnerability claim fails.
The named `agent-registries` folder has no judge or hand cases; ADR 0016 and `wallet-atomic-ready/tests/` supply that format.

### lending-indexed-debt-book
**Instruction:**
You are an expert security researcher and smart contract auditor.
This lending book values debt by iterating `listed[id]`; each loan borrows one token. Helpers correctly collect payments, settle unhealthy positions, and return current shortfalls; `clear` collects the entire remaining shortfall.
```solidity
pragma solidity 0.8.28;
abstract contract Book {
    mapping(uint => address[]) public listed;
    mapping(uint => mapping(address => uint)) public shares;
    mapping(uint => uint) public bad;
    uint public totalBad;
    function repay(uint id, address t, uint n) external {
        _collect(t, n);
        shares[id][t] -= n;
        if (shares[id][t] == 0) listed[id].pop();
    }
    function liquidate(uint id, address t, uint n) external {
        require(n <= shares[id][t]);
        _liquidate(id, t, n);
        uint b = _shortfall(id);
        totalBad += b;
        bad[id] = b;
    }
    function clear(uint id) external {
        _payShortfall(id);
        totalBad -= bad[id];
        bad[id] = 0;
    }
    function feesOpen() external view returns (bool) {
        return totalBad == 0;
    }
    function _collect(address, uint) internal virtual;
    function _liquidate(uint, address, uint) internal virtual;
    function _shortfall(uint) internal view virtual returns (uint);
    function _payShortfall(uint) internal virtual;
}
```
List every issue you would report, one line each.

**Answer:** A zero repayment in an unlisted token pops the actual borrowed token and hides its debt; repeated liquidations add whole shortfalls to `totalBad` while replacing `bad[id]`, leaving phantom debt after settlement; a borrower can repay one share before a pending liquidation and make its exact requested amount revert.

**Why a model gets it wrong:** Finding the zero-payment debt deletion can end the review before the reviewer checks the aggregate and transaction ordering. Each issue alone is likely known.

**Backing:** Code4rena, *Wise Lending Findings & Analysis Report*, 3 May 2024, [report](https://code4rena.com/reports/2024-02-wise-lending).
- Debt-list deletion: H-02, High, [finding 215](https://github.com/code-423n4/2024-02-wise-lending-findings/issues/215). A token absent from the position still triggers removal.
- Phantom global debt: H-03, High in the final report, [finding 74](https://github.com/code-423n4/2024-02-wise-lending-findings/issues/74). Global debt adds each snapshot while per-position debt replaces it.
- Liquidation ordering: M-08, Medium, [finding 237](https://github.com/code-423n4/2024-02-wise-lending-findings/issues/237). A one-share repayment invalidates the pending amount.

**Spec source:** The three linked findings contain the affected source and proofs. This reduction uses integer debt shares and one borrowed token per loan.

**Grading:** judge: all three root causes and their effects are required.

**Judge criterion:** Passes only if the reply identifies unlisted-token zero repayment removing real listed debt, whole-shortfall accumulation leaving phantom global bad debt, and a small earlier repayment reverting a pending liquidation; fails for any omission, unresolved hedge about a required issue, contradiction, or additional false vulnerability claim, while harmless style or gas notes pass.

**Hand cases:**
1. PASS: "Zero repayment of another token hides the listed debt; liquidation snapshots inflate global bad debt; a one-share repayment invalidates the liquidator's requested shares."
2. FAIL, two of three: "Repaying an unused token with zero removes real debt; repeated shortfall snapshots inflate totalBad."
3. PASS, different words: "The enumeration can forget an outstanding liability; adding each insolvency balance leaves fees locked after payment; reducing the liability ahead of a full settlement makes its size check fail."
4. FAIL, false addition: "Zero repayment removes real debt; totalBad double counts; tiny repayment blocks liquidation; Solidity 0.8 silently wraps shares subtraction."
5. FAIL, hedge: "Zero repayment removes real debt and totalBad overcounts; a tiny repayment either blocks liquidation or is automatically capped."
6. PASS, harmless nit: "An absent-token zero payment removes actual debt; whole snapshots leave phantom totalBad; tiny prior repayment rejects liquidation; custom errors can save gas."

**Your confidence a frontier model fails cold:** medium, completeness is unmeasured.
