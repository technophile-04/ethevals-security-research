### governance-council
**Instruction:**
````
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28, OpenZeppelin 5.4.0; `token` is a standard ERC20Votes token. Anyone may cancel a proposal whose proposer falls below the threshold.

```solidity
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract Council {
    struct Proposal { address proposer; uint256 snapshot; uint256 end; uint256 votes; bool closed; }
    uint256 constant THRESHOLD = 10_000e18;
    uint256 quorum = 400_000e18;
    IVotes immutable token;
    mapping(bytes32 => Proposal) proposals;
    mapping(bytes32 => mapping(address => bool)) voted;

    constructor(IVotes t) { token = t; }

    function propose(address target, bytes calldata data) external {
        require(token.getPastVotes(msg.sender, block.number - 1) >= THRESHOLD);
        bytes32 id = keccak256(abi.encode(target, data));
        require(proposals[id].end == 0);
        proposals[id] = Proposal(msg.sender, block.number - 1, block.number + 50_400, 0, false);
    }

    function support(bytes32 id) external {
        Proposal storage p = proposals[id];
        require(block.number <= p.end && !p.closed && !voted[id][msg.sender]);
        voted[id][msg.sender] = true;
        p.votes += token.getPastVotes(msg.sender, p.snapshot);
    }

    function cancel(bytes32 id) external {
        Proposal storage p = proposals[id];
        require(msg.sender == p.proposer || token.getPastVotes(p.proposer, block.number - 1) <= THRESHOLD);
        p.closed = true;
    }

    function execute(address target, bytes calldata data) external {
        Proposal storage p = proposals[keccak256(abi.encode(target, data))];
        require(block.number > p.end && !p.closed && p.votes >= quorum);
        p.closed = true;
        (bool ok,) = target.call(data);
        require(ok);
    }

    function setQuorum(uint256 q) external {
        require(msg.sender == address(this));
        quorum = q;
    }
}
```

List every issue you would report, one line each.
````
(218 words, 45 code lines.)

**Answer:** Three issues. (1) The proposal id is only `keccak256(target, data)`, so another holder of the threshold can submit the same proposal first, becoming its proposer, cancel it, and the id can never be proposed again. (2) `execute` reads the current `quorum`, and proposals never expire, so a later proposal that lowers the quorum makes old proposals that failed for lack of quorum executable. (3) `propose` accepts exactly `THRESHOLD` but `cancel` lets anyone cancel when the proposer holds `<= THRESHOLD`, so a proposer who never fell below the threshold can be cancelled by anyone.

**Why a model gets it wrong:** Each issue alone is likely known. The risk is stopping early: the cancel path holds two separate issues (who owns the id, and the `<=`), and a reviewer who reports one of them tends to close the function. The quorum issue lives across two functions and two proposals and only shows when the reviewer asks what happens to old proposals when a parameter changes. The snapshot at `block.number - 1` also invites a false "flash-loan voting" line.

**Backing:**
- Issue 1: OpenZeppelin security advisory GHSA-5h3x-9wvq-w4m2 (CVE-2023-34234), "Governor proposal creation may be blocked by frontrunning", severity Moderate, 7 Jun 2023, fixed in 4.9.1 with proposer-bound descriptions. "By frontrunning the creation of a proposal, an attacker can become the proposer and gain the ability to cancel it." https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-5h3x-9wvq-w4m2
- Issue 2: OpenZeppelin security advisory GHSA-xrc4-737v-9q75 (CVE-2022-31198), "GovernorVotesQuorumFraction updates to quorum may affect past defeated proposals", severity High, 28 Jul 2022, fixed in 4.7.2 by checkpointing the quorum. "Past proposals may become executable if they had been defeated only due to lack of quorum." https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-xrc4-737v-9q75
- Issue 3: Code4rena, Nouns DAO (Aug 2022), M-02 "User A cannot cancel User B's proposal when User B's prior number of votes at relevant block is same as proposal threshold...", Medium. Nouns' `propose` used `> threshold` and `cancel` used `< threshold`, leaving a gap at equality; this snippet puts the gap the other way, so the equal case is cancellable by anyone. https://github.com/code-423n4/2022-08-nounsdao-findings/issues/255 (report: https://code4rena.com/reports/2022-08-nounsdao)

**Spec source:** OpenZeppelin 5.4.0 `Governor.propose` binds the description to the proposer (`_isValidDescriptionForProposer`, Governor.sol line 283 in `pilot/deps/oz5`), and `GovernorVotesQuorumFraction.quorum(timepoint)` reads a checkpointed numerator at the proposal snapshot (lines 48 to 62), which are the two fixes. GovernorBravo's rule pair is `propose: votes > threshold`, `cancel: votes < threshold`.

**Grading:** judge: all three issues required.

**Judge criterion:** The file holds one reply to the question above (code included in the criterion as given). Passes only if the reply names all three: (1) the proposal id is only `target` and `data` (no proposer or nonce), so another threshold holder can create the same proposal first and cancel it, or the same action can never be proposed again once used; either effect counts with that root cause; (2) `execute` checks the current `quorum` rather than the quorum when the proposal was made, so lowering the quorum makes old proposals that ended below it executable; (3) `cancel` uses `<= THRESHOLD` while `propose` accepts `>= THRESHOLD`, so anyone can cancel a proposal whose proposer holds exactly the threshold. Fails if any of the three is missing or only hedged, or if the reply claims a concrete loss the code does not have, such as flash-loaned or freshly transferred votes counting (votes are read at a past block), double voting, or reentrancy in `execute` (the proposal is closed before the call). Design or hygiene notes with no concrete loss (no voting delay, no timelock, no events, no bounds on `setQuorum`, no way to vote against) do not fail it.

**Hand cases:**
1. PASS, plain: "Proposal id omits the proposer, so someone with 10k votes can propose the same call first and cancel it, blocking it forever; execute uses the current quorum, so lowering it revives old proposals that missed quorum; cancel's `<=` lets anyone cancel a proposer holding exactly THRESHOLD although propose accepted them."
2. FAIL, two of three: "Front-runner can take the proposal id and cancel it; a quorum change applies to old proposals so defeated ones become executable; no events are emitted."
3. PASS, different words: "Identical target/data can only ever exist once, and the first submitter controls cancellation; quorum isn't snapshotted per proposal, so a quorum cut retroactively passes failed votes; off-by-one: a proposer at exactly the threshold counts as below it in cancel."
4. FAIL, all three plus a false claim: "Id collision lets a front-runner cancel; quorum read at execution revives defeated proposals; `<=` lets anyone cancel at exactly the threshold; votes can be flash-loaned because voting weight is read at the latest block."
5. FAIL, hedge: "Front-runner can own and cancel the id; cancel's `<=` is off by one; quorum changes could possibly affect past proposals depending on how governance uses setQuorum."
6. PASS, harmless nits: "Same-id front-run and cancel blocks the action; lowered quorum revives old defeated proposals; `<=` lets strangers cancel exact-threshold proposers; also add a voting delay, a timelock and events."

**Verified by:** `/tmp/subagents/security-quizzes/pilot/multi-opus2-governance-council/`, `test/Council.t.sol` against `src/Council.sol` (the instruction's code), OpenZeppelin 5.4.0 ERC20Votes as the token.
Command: `cd /tmp/subagents/security-quizzes/pilot/multi-opus2-governance-council && forge test`
```
[PASS] test_control_defeatedProposalStaysDefeated() (gas: 320552)
[PASS] test_control_strangerCannotCancelAboveThreshold() (gas: 321711)
[PASS] test_issue1_sameActionProposedFirstThenCancelledIsBlockedForever() (gas: 405118)
[PASS] test_issue2_loweredQuorumRevivesOldDefeatedProposal() (gas: 624050)
[PASS] test_issue3_proposerAtExactThresholdCancelledByAnyone() (gas: 296735)
Suite result: ok. 5 passed; 0 failed; 0 skipped
```
Issue 1: Mallory (exactly 10k votes) proposes the grant first, cancels it, and Alice's identical proposal reverts then and a million blocks later. Issue 2: a 300k-vote grant fails quorum, a second proposal lowers quorum to 250k, and the old grant then executes, paying 1,000,000. Issue 3: a stranger with no votes cancels Alice's proposal while she holds exactly 10k; the control shows the same cancel reverts at 10k + 1 wei.

**Your confidence a frontier model fails cold:** medium-low. The front-run and the `<=` are visible; the retroactive quorum is the one most likely to be missed.

