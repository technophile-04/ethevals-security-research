# Multi-issue candidates, second Opus drafter (brief6)

Ground: governance and voting, staking, auctions, bridges and cross-chain messaging, account and signature paths.
Each question is one contract with three independent issues of different kinds, each modelled on a published High or Medium finding. Severities are the published ratings, not new ratings for these reductions.
Each has a Foundry project under `/tmp/subagents/security-quizzes/pilot/multi-opus2-<slug>/`, one test per issue plus controls, run with Foundry 1.5.1 and solc 0.8.28. The `src/` file is extracted from the instruction's code block by `multi-opus2-tools/extract.py`, so the code tested is the code asked about.
Word counts use `multi-opus2-tools/words.py` (whitespace words, code fences removed). The repo stayed read only. No model trials or judge calls ran; confidence lines are predictions.

**Judge policy, the same for every question (written into each criterion):** a reply passes only if it names every listed issue. Extra lines that are hygiene or design notes with no concrete loss (events, zero-address checks, gas, custom errors, SafeERC20 for a token the setup calls standard, missing timelock, trust in a role the setup calls trusted) do not fail it. A line that claims a concrete loss or broken behaviour the code does not have fails it. A hedge on a listed issue ("might", "if X then maybe", "consider whether") counts as not naming it.

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

### accounts-relayed-wallet
**Instruction:**
````
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28, OpenZeppelin 5.4.0. `owner` is an EOA or a contract wallet such as a Safe. Anyone may relay a signed call. Nonce lanes let separate apps queue calls without blocking each other, and a failed call is logged instead of reverting so later calls are not held up.

```solidity
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract RelayWallet {
    address public immutable owner;
    mapping(uint256 => uint256) public nonces;

    event Failed(uint256 lane, uint256 nonce, bytes reason);

    constructor(address o) { owner = o; }

    receive() external payable {}

    function exec(uint256 lane, address to, uint256 value, bytes calldata data, bytes calldata sig) external {
        uint256 n = nonces[lane]++;
        bytes32 h = keccak256(abi.encode(block.chainid, address(this), n, to, value, data));
        if (sig.length == 65) {
            require(ECDSA.recover(h, sig) == owner, "bad signature");
        } else {
            (address signer, bytes memory inner) = abi.decode(sig, (address, bytes));
            require(IERC1271(signer).isValidSignature(h, inner) == IERC1271.isValidSignature.selector, "bad signature");
        }
        (bool ok, bytes memory reason) = to.call{value: value}(data);
        if (!ok) emit Failed(lane, n, reason);
    }
}
```

List every issue you would report, one line each.
````
(180 words, 26 code lines.)

**Answer:** Three issues. (1) The ERC-1271 branch takes the signer address from the signature and never checks it is `owner`, so any contract that returns the magic value authorises any call, and anyone can empty the wallet. (2) `lane` is not in the signed hash, so a signature for nonce `n` on one lane replays once on every other lane whose nonce is `n`; every first call can be repeated without limit. (3) The relayer chooses the gas: with no signed gas amount and no check before the call, it can send just enough that the inner call runs out of gas (only 63/64 is forwarded) while `exec` completes, so the nonce is spent, `Failed` is logged, and the owner's call never runs.

**Why a model gets it wrong:** The 1271 branch is loud and draws the first line. The lane issue needs the reader to compare the hash fields with the nonce lookup. The gas issue hides behind a stated design choice ("a failed call is logged instead of reverting"), which invites the reader to accept the swallowed failure; the real issue is who controls whether it fails.

**Backing:**
- Issue 1: Code4rena, Biconomy Smart Account (Jan 2023), H-04 "Arbitrary transactions possible due to insufficient signature validation", High. `checkSignatures` read the contract signer from the signature bytes and called its `isValidSignature` without checking it was the owner. https://github.com/code-423n4/2023-01-biconomy-findings/issues/175 (report: https://code4rena.com/reports/2023-01-biconomy)
- Issue 2: same report, H-07 "Replay attack (EIP712 signed transaction)", High. The wallet checked `nonces[batchId]` but `batchId` was not in the signed data, so first transactions replay across batches. https://github.com/code-423n4/2023-01-biconomy-findings/issues/36
- Issue 3: Code4rena, Ambire Wallet (May 2023), M-02 "Attacker can force the failure of transactions that use `tryCatch`", Medium. A relayer picks a gas limit at which the inner call fails while the outer call succeeds and the nonce advances; the mitigation review found it not fully mitigated. https://github.com/code-423n4/2023-05-ambire-findings/issues/18 (report: https://code4rena.com/reports/2023-05-ambire)

**Spec source:** EIP-1271 (https://eips.ethereum.org/EIPS/eip-1271): the verifier calls `isValidSignature` on the account that is supposed to have signed, here `owner`. EIP-150 (https://eips.ethereum.org/EIPS/eip-150): a call forwards at most all but 1/64 of the remaining gas, so `to.call` without a gas floor runs on whatever the relayer left.

**Grading:** judge: all three issues required.

**Judge criterion:** The file holds one reply to the question above. Passes only if the reply names all three: (1) the ERC-1271 branch never checks that the decoded `signer` is `owner`, so any contract returning the magic value authorises any call; (2) `lane` is not part of the signed hash, so one signature can be replayed on other lanes at the same nonce; (3) whoever relays controls the gas and can make the inner call fail (for example by sending just too little gas, the 63/64 rule) while `exec` succeeds, spending the nonce without running the owner's call; a reply that says no gas limit is signed or checked and the relayer can force failures counts, but a reply that only says the call's return value is ignored, without the relayer forcing the failure, does not. Fails if any of the three is missing or only hedged, or if the reply claims a concrete loss the code does not have, such as cross-chain or cross-wallet replay (chain id and wallet address are signed), signature malleability (OpenZeppelin's `ECDSA.recover` rejects high-s), or reentrancy into `exec` (the nonce is bumped first). Hygiene or design notes with no concrete loss (use EIP-712, events, signing a raw hash, deadlines) do not fail it.

**Hand cases:**
1. PASS, plain plus a nit: "1271 path never checks signer == owner, so a contract that always returns the magic value can execute anything; lane missing from the hash lets a signature replay on every lane; relayer can pass just enough gas that the inner call OOGs while exec succeeds, burning the nonce; consider EIP-712 typed data."
2. FAIL, two of three: "Contract-signature branch accepts any signer, letting anyone drain the wallet; relayer can underfund gas so the call fails but the nonce is consumed."
3. PASS, different words: "Smart-contract signatures are checked against a caller-chosen validator rather than the owner; the per-lane nonce isn't bound into what's signed, so the same approval runs once per lane; because the gas forwarded isn't part of the signature, a submitter can make the inner call fail on purpose and burn the user's nonce."
4. FAIL, all three plus a false claim: "Signer not checked against owner in the 1271 branch; lane not signed; relayer gas griefing burns nonces; signatures can be replayed on other chains after a fork."
5. FAIL, hedge: "1271 branch doesn't check the owner; lane is not in the hash so replay across lanes; swallowing failures might be risky in some situations."
6. FAIL, near miss on issue 3: "Arbitrary 1271 signer accepted; lane omitted from hash enables replay; the low-level call's success is not checked, so failed calls go unnoticed."

**Verified by:** `/tmp/subagents/security-quizzes/pilot/multi-opus2-accounts-relayed-wallet/`, `test/RelayWallet.t.sol` against `src/RelayWallet.sol` (the instruction's code).
Command: `cd /tmp/subagents/security-quizzes/pilot/multi-opus2-accounts-relayed-wallet && forge test`
```
[PASS] test_control_ampleGasRunsTheCall() (gas: 600598)
[PASS] test_control_strangerEoaSignatureRejected() (gas: 39760)
[PASS] test_issue1_anyContractSignerAuthorizesAnyCall() (gas: 174242)
[PASS] test_issue2_signatureReplaysOnEveryOtherLane() (gas: 185426)
[PASS] test_issue3_relayerForcesInnerFailureAndBurnsNonce() (gas: 13686704)
Suite result: ok. 5 passed; 0 failed; 0 skipped
```
Issue 1: a stranger passes `abi.encode(AlwaysValid, "")` and takes the wallet's 10 ETH. Issue 2: Alice signs one 1 ETH payment to Bob on lane 0; a stranger replays it on lanes 1 to 3 and Bob receives 4 ETH. Issue 3: the test raises the relayer's gas limit in 1,000 steps until `exec` first succeeds; at that point the nonce is 1, the 20-slot `Ledger.record` call has not run, and the same signature now reverts. The control shows the same signed call runs with ample gas.

**Your confidence a frontier model fails cold:** medium. Issues 1 and 2 will usually be found; issue 3 is often written as "unchecked call result", which the criterion does not accept.

### auctions-gallery-bids
**Instruction:**
````
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28, OpenZeppelin 5.4.0. Trusted artists keep their tokens and approve this contract; the holder should receive the winning bid.

```solidity
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
contract Gallery is Ownable(msg.sender) {
    struct Bid { address bidder; uint256 amount; }
    IERC721 immutable nft;
    mapping(uint256 => uint256) public endTime;
    mapping(uint256 => Bid[]) public bids;
    mapping(uint256 => bool) settled;

    constructor(IERC721 n) { nft = n; }

    function list(uint256 id, uint256 end) external onlyOwner {
        require(endTime[id] == 0);
        endTime[id] = end;
    }

    function bid(uint256 id) external payable {
        Bid[] storage b = bids[id];
        require(block.timestamp <= endTime[id] && (b.length == 0 || msg.value > b[b.length - 1].amount));
        b.push(Bid(msg.sender, msg.value));
    }

    function cancel(uint256 id, uint256 i) external {
        Bid storage x = bids[id][i];
        require(block.timestamp <= endTime[id] && i + 1 < bids[id].length && x.bidder == msg.sender);
        uint256 amount = x.amount;
        x.amount = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok);
    }

    function settle(uint256 id) external {
        require(block.timestamp >= endTime[id] && !settled[id]);
        settled[id] = true;
        Bid[] storage b = bids[id];
        Bid storage top = b[b.length - 1];
        nft.transferFrom(nft.ownerOf(id), top.bidder, id);
        (bool ok,) = owner().call{value: top.amount}("");
        require(ok);
        for (uint256 i = 0; i + 1 < b.length; i++) {
            (ok,) = b[i].bidder.call{value: b[i].amount}("");
            require(ok);
        }
    }
}
```

List every issue you would report, one line each.
````
(219 words, 45 code lines.)

**Answer:** Three issues. (1) At `block.timestamp == endTime` both `settle` (`>=`) and `cancel`/`bid` (`<=`) are open, and `settle` refunds outbid bids without zeroing them, so in that second a bidder can settle and then cancel an outbid bid and be refunded twice, paid out of other auctions' escrow (a bid placed in that second after settlement is also stranded). (2) `settle` pushes a refund to every outbid bidder and requires each call to succeed, so one bidder whose address rejects ETH (or a long array of tiny cancelled bids) makes settlement revert forever; after the end nobody can cancel, so every bid and the token are stuck. (3) The winning bid is paid to `owner()`, the gallery's deployer, not to the token's holder, so artists are never paid.

**Why a model gets it wrong:** The push-refund loop is the textbook line and arrives first. The end-second overlap needs the reader to set `<=` in `cancel` against `>=` in `settle` and then notice that `settle` leaves refunded amounts in place. The payout line looks like ordinary `Ownable` plumbing unless the reader holds it against the setup sentence.

**Backing:** all three from Code4rena, NextGen (Oct 2023), `AuctionDemo.sol`; report https://code4rena.com/reports/2023-10-nextgen
- Issue 1: H-02 "Attacker can drain all ETH from `AuctionDemo` when `block.timestamp == auctionEndTime`", High. `participateToAuction` and `cancelBid` allowed `<=` and `claimAuction` allowed `>=`, and `claimAuction` refunded without clearing the bid status. https://github.com/code-423n4/2023-10-nextgen-findings/issues/1323 . The stranded-bid effect is the same report's M-10, "Bidder Funds Can Become Unrecoverable Due to 1 second Overlap in `participateToAuction()` and `claimAuction()`", Medium.
- Issue 2: H-03 "Adversary can block `claimAuction()` due to push-strategy to transfer assets to multiple bidders", High. https://github.com/code-423n4/2023-10-nextgen-findings/issues/734 . The gas form is H-05, "Permanent DoS due to non-shrinking array usage in an unbounded loop", High (automated findings).
- Issue 3: M-05 "Auction payout goes to `AuctionDemo` contract owner, not the token owner", Medium. Report section only; I did not retrieve its GitHub issue link.

**Spec source:** the three linked findings and their recommended fixes (strict `>` in the claim path and clearing each bid before refunding; pull-based refunds; paying the token owner).

**Grading:** judge: all three issues required.

**Judge criterion:** The file holds one reply to the question above. Passes only if the reply names all three: (1) when `block.timestamp == endTime`, `settle` and `cancel` (or `bid`) are both allowed, so a bidder can settle and then cancel, getting an outbid bid refunded twice (or a bid lands after settlement and is stranded); the reply must tie the problem to the shared end second or the `<=`/`>=` boundary; (2) `settle` pushes refunds to all outbid bidders in one transaction, so one bidder that rejects ETH, or a very long bid array, blocks settlement and locks every bid and the token; (3) the winning bid goes to `owner()` instead of the token holder or artist. Fails if any of the three is missing or only hedged, or if the reply claims a concrete loss the code does not have, such as reentering `cancel` to be refunded twice (the amount is zeroed before the call), a bidder cancelling the top bid, or taking funds through reentrancy after the end second. Design or hygiene notes with no concrete loss (use `safeTransferFrom`, no reserve price, no minimum increment, no events, `settle` reverting when there are no bids) do not fail it.

**Hand cases:**
1. PASS, plain: "At the exact end timestamp both cancel and settle work, so a bidder settles then cancels an outbid bid and is refunded twice from other auctions' ETH; push refunds in settle let one reverting bidder block settlement forever; proceeds go to the gallery owner instead of the artist holding the token."
2. FAIL, two of three: "Push refunds let a contract bidder that reverts lock the auction; winning bid is sent to owner() rather than the token holder; use safeTransferFrom for the NFT."
3. PASS, different words: "Off-by-one window: `<=` in cancel and `>=` in settle overlap for one second, enabling a second refund of a bid settle already returned; settlement depends on every loser accepting ETH, so a griefer freezes all bids and the token; the payee is the contract's owner, so artists never receive the sale price."
4. FAIL, all three plus a false claim: "End-second overlap gives double refunds; one reverting bidder blocks settle; payout to owner not artist; cancel is reentrant because the refund is sent before the bid is cleared."
5. FAIL, hedge: "Proceeds go to owner instead of artist; refund loop can be blocked by a reverting bidder; the timestamp checks may need review at the boundary."
6. PASS, harmless nits: "Settle then cancel in the final second refunds a bid twice; settle's refund loop can be bricked by a bidder rejecting ETH or by a huge bids array; winning ETH goes to owner() not the holder; consider a reserve price and events."

**Verified by:** `/tmp/subagents/security-quizzes/pilot/multi-opus2-auctions-gallery-bids/`, `test/Gallery.t.sol` against `src/Gallery.sol` (the instruction's code), OpenZeppelin 5.4.0 ERC721 as the token.
Command: `cd /tmp/subagents/security-quizzes/pilot/multi-opus2-auctions-gallery-bids && forge test`
```
[PASS] test_control_cancelClosedAfterEnd() (gas: 231393)
[PASS] test_issue1_endSecondOverlapRefundsTwice() (gas: 363620)
[PASS] test_issue2_oneRefusingBidderLocksTheAuction() (gas: 385468)
[PASS] test_issue3_proceedsGoToOwnerNotHolder() (gas: 179145)
Suite result: ok. 4 passed; 0 failed; 0 skipped
```
Issue 1: Carol escrows 5 ETH on auction 2; Mallory bids 3 and 3.1 ETH on auction 1, settles and cancels in its last second, gets the token for a net 0.1 ETH, and auction 2 can no longer settle. Control: one second later the same cancel reverts. Issue 2: a contract that rejects ETH bids 0.01 ETH; after the end `settle` reverts, Bob's outbid 2 ETH cannot be cancelled, and 6.01 ETH plus the token stay locked. Issue 3: Bob wins for 2 ETH, the artist receives nothing, the curator receives 2 ETH.

**Your confidence a frontier model fails cold:** medium-low. The end-second overlap is the likely miss; the other two are usually found.

### staking-withdraw-queue
**Instruction:**
````
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28, OpenZeppelin 5.4.0. `staker` is trusted: `unstake` sends the ETH back to its caller within the call, and `staked()` falls when a validator is slashed. At launch the deployer deposited 32 ETH and burned the shares.

```solidity
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IStaker {
    function stake() external payable;
    function unstake(uint256 amount) external;
    function staked() external view returns (uint256);
}

contract StakePool is ERC20("Pool ETH", "pETH"), ReentrancyGuard {
    IStaker immutable staker;
    address immutable keeper;
    mapping(address => uint256) public owed;

    constructor(IStaker s, address k) { staker = s; keeper = k; }

    receive() external payable nonReentrant {}

    function totalAssets() public view returns (uint256) {
        return address(this).balance + staker.staked();
    }

    function deposit() external payable nonReentrant {
        uint256 supply = totalSupply();
        _mint(msg.sender, supply == 0 ? msg.value : msg.value * supply / (totalAssets() - msg.value));
    }

    function requestWithdraw(uint256 shares) external nonReentrant {
        owed[msg.sender] += shares * totalAssets() / totalSupply();
        _burn(msg.sender, shares);
    }

    function claim() external nonReentrant {
        uint256 amount = owed[msg.sender];
        owed[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok);
    }

    function rebalance(uint256 toStake, uint256 fromStake) external nonReentrant {
        require(msg.sender == keeper);
        if (toStake > 0) staker.stake{value: toStake}();
        if (fromStake > 0) staker.unstake(fromStake);
    }
}
```

List every issue you would report, one line each.
````
(214 words, 45 code lines.)

**Answer:** Three issues. (1) ETH already owed to requested withdrawals stays in `address(this).balance` or `staked()` and is still counted by `totalAssets`, while the requester's shares are burned, so every remaining share is overvalued: later requests are owed more than the pool holds, new depositors get too few shares, and the last claimers cannot be paid. (2) The owed amount is fixed at request time, so a slash after the request falls only on holders still in the pool; anyone who sees a slash coming can request first and leave the loss to the rest. (3) `receive()` is `nonReentrant`, and `rebalance` (also `nonReentrant`) calls `unstake`, which sends ETH back into `receive()` during the call, so unstaking always reverts and staked ETH can never come back to pay claims.

**Why a model gets it wrong:** The `nonReentrant` on every function reads as care, and a reviewer who checks `claim` for reentrancy and finds it guarded tends to move on rather than ask what the guard on `receive()` blocks. Issues 1 and 2 are both about the queue, so a reply that finds one is likely to write one queue line and stop; they are separate (Lido's queue needs both a reserve excluded from the rate and a min-of-two-rates rule).

**Backing:** all three from Code4rena, Renzo (Apr 2024); report https://code4rena.com/reports/2024-04-renzo
- Issue 1: H-02 "Incorrect calculation of queued withdrawals can deflate TVL and increase ezETH mint rate", High. https://github.com/code-423n4/2024-04-renzo-findings/issues/395 . Renzo's error left queued value out of TVL; this snippet errs the other way (value already owed is still counted), so the rate is inflated instead. The same report's H-08, "Incorrect withdraw queue balance in TVL calculation" (https://github.com/code-423n4/2024-04-renzo-findings/issues/28), is a second queue-in-TVL error.
- Issue 2: H-04 "Withdrawals logic allows MEV exploits of TVL changes and zero-slippage zero-fee swaps", High: "the withdrawal amount is calculated at withdrawal request submission time". https://github.com/code-423n4/2024-04-renzo-findings/issues/326 . Also H-05 "Withdrawals of rebasing tokens can lead to insolvency and unfair distribution of protocol reserves" (https://github.com/code-423n4/2024-04-renzo-findings/issues/282): a stored amount ignores later slashing and shifts the loss.
- Issue 3: H-03 "ETH withdrawals from EigenLayer always fail due to `OperatorDelegator`'s nonReentrant `receive()`", High. `completeQueuedWithdrawal` was `nonReentrant`, the EigenPod paid ETH back into a `nonReentrant` `receive()`, and the callback reverted. https://github.com/code-423n4/2024-04-renzo-findings/issues/368

**Spec source:** OpenZeppelin 5.4.0 `ReentrancyGuard` (`pilot/deps/oz5/utils/ReentrancyGuard.sol`): one status slot per contract, so any `nonReentrant` function entered while another is running reverts with `ReentrancyGuardReentrantCall`; the test asserts that exact selector.

**Grading:** judge: all three issues required.

**Judge criterion:** The file holds one reply to the question above. Passes only if the reply names all three: (1) ETH owed to pending (unclaimed) withdrawals is still counted in `totalAssets` after the shares are burned, so the share price is inflated (later requests over-paid, new deposits under-credited, or the pool insolvent); (2) the withdrawal amount is fixed when requested, so a slash or loss after the request is borne only by remaining holders, or holders can exit ahead of a slash; (3) `receive()` being `nonReentrant` makes `unstake` revert when called from the `nonReentrant` `rebalance`, so ETH can never be brought back from staking. Fails if any of the three is missing or only hedged, or if the reply claims a concrete loss the code does not have, such as reentrancy in `claim` (it zeroes first and is guarded), a first-depositor share-inflation loss (the pool was seeded with 32 ETH and the shares burned), or the keeper or `staker` misbehaving (both trusted). Design or hygiene notes with no concrete loss (no withdrawal delay, no events, no minimum-out argument, rounding direction notes) do not fail it.

**Hand cases:**
1. PASS, plain: "totalAssets still includes ETH owed to requested withdrawals, inflating the price so later withdrawers take others' ETH; owed is locked at request time so requesters dodge later slashing; nonReentrant receive() makes staker.unstake revert inside rebalance, so ETH can never return."
2. FAIL, two of three: "Owed ETH is double counted in totalAssets after the burn; nonReentrant on receive blocks unstaking because rebalance holds the lock; add events."
3. PASS, different words: "Pending claims aren't reserved out of the exchange rate, so the pool promises more than it has; the queue pays the pre-slash rate, socialising slashes onto those who stay; the reentrancy guard on the ETH fallback rejects the staker's refund while rebalance holds the guard."
4. FAIL, all three plus a false claim: "Owed ETH still in totalAssets; request-time pricing escapes slashing; nonReentrant receive blocks unstake; first depositor can inflate the share price and steal the next deposit."
5. FAIL, hedge: "totalAssets counts owed ETH; receive's guard breaks unstake; withdrawal pricing could perhaps be gamed around slashing depending on the staker."
6. PASS, harmless nits: "Owed-but-unclaimed ETH inflates totalAssets; fixed request-time amount lets users front-run a slash; guarded receive() reverts the unstake callback, locking staked ETH; consider a withdrawal delay and emitting events."

**Verified by:** `/tmp/subagents/security-quizzes/pilot/multi-opus2-staking-withdraw-queue/`, `test/StakePool.t.sol` against `src/StakePool.sol` (the instruction's code), with a mock `staker` that behaves as the setup says (pays the caller within `unstake`, `slash` lowers `staked()`), and the 32 ETH seed burned in `setUp`.
Command: `cd /tmp/subagents/security-quizzes/pilot/multi-opus2-staking-withdraw-queue && forge test`
```
[PASS] test_control_noSlashFairExit() (gas: 50009)
[PASS] test_control_stakePathWorks() (gas: 47690)
[PASS] test_issue1_owedEthStillCountedInTotalAssets() (gas: 124989)
[PASS] test_issue2_requestBeforeSlashEscapesTheLoss() (gas: 141813)
[PASS] test_issue3_unstakeAlwaysRevertsOnNonReentrantReceive() (gas: 87265)
Suite result: ok. 5 passed; 0 failed; 0 skipped
```
Issue 1: after Alice requests her 32 ETH, `totalAssets` still reads 96 ETH; Carol's 32 ETH deposit mints about 21.3 shares; Bob's 32 shares are then owed 48 ETH and he withdraws 16 ETH of Carol's and the seed's money. Issue 2: Alice requests 32 ETH, a 25% slash lands, and she is still paid 32 ETH. Issue 3: `rebalance(0, 1 ether)` reverts with `ReentrancyGuardReentrantCall`, and Alice's claim then fails with all ETH staked; the control shows the stake direction works.

**Your confidence a frontier model fails cold:** medium. Issue 3 is the likely miss, and a first-depositor line despite the seed is a likely false claim.

### bridges-message-inbox
**Instruction:**
````
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28. `prover` is trusted and reports which hashes the source chain sent here. Anyone may relay a proven message after one hour and earn its fee. The guardian may only hold messages back.

```solidity
interface IProver { function proven(bytes32 h) external view returns (bool); }

contract Inbox {
    struct Message { uint256 nonce; address to; uint256 value; uint256 fee; uint256 gasLimit; bytes data; }
    IProver immutable prover;
    address immutable guardian;
    mapping(bytes32 => uint64) receivedAt;
    mapping(bytes32 => uint8) status;

    constructor(IProver p, address g) { prover = p; guardian = g; }

    function prove(bytes32 h) external {
        require(receivedAt[h] == 0 && prover.proven(h));
        receivedAt[h] = uint64(block.timestamp);
    }

    function hold(bytes32 h, bool on) external {
        require(msg.sender == guardian);
        receivedAt[h] = on ? type(uint64).max : uint64(block.timestamp);
    }

    function process(Message calldata m) external {
        bytes32 h = keccak256(abi.encode(m));
        uint64 t = receivedAt[h];
        require(status[h] == 0 && t != 0 && t != type(uint64).max && block.timestamp >= t + 1 hours);
        status[h] = 1;
        (bool ok,) = m.to.call{value: m.value, gas: m.gasLimit}(m.data);
        if (!ok) status[h] = 2;
        payable(msg.sender).transfer(m.fee);
    }

    function retry(Message calldata m) external {
        bytes32 h = keccak256(abi.encode(m));
        require(msg.sender == m.to && status[h] == 2);
        status[h] = 1;
        (bool ok,) = m.to.call{value: m.value}(m.data);
        require(ok);
    }
}
```

List every issue you would report, one line each.
````
(218 words, 39 code lines.)

**Answer:** Three issues. (1) The relayer chooses the transaction's gas and nothing checks that `m.gasLimit` is actually available: the call receives at most 63/64 of what is left, so for a message with a large gas limit a relayer can send just enough that the call runs out of gas while `process` finishes, collects the fee, and marks the message failed; only `m.to` can retry, so a contract recipient with no code to call `retry` loses the value. (2) `hold(h, false)` writes a fresh timestamp into the same slot that records proof, so the guardian, meant only to delay, can make a message the source chain never sent processable an hour later. (3) `retry` does not check the hold, so a failed message the guardian has held back still executes through `retry`.

**Why a model gets it wrong:** The guardian is the obvious centralisation line, and a reviewer who writes "guardian can censor" counts it done without seeing that releasing creates a proof. The gas issue needs the 63/64 rule plus the observation that the fee is paid on failure. The `retry` gap only shows when the reader re-checks each entry point against the hold.

**Backing:**
- Issue 1: Sherlock, Optimism Bedrock contest (Jan 2023), H-1 "Malicious user can finalize other's withdrawal with less than specified gas limit, leading to loss of funds", High (obront): `finalizeWithdrawalTransaction` could run a withdrawal's call with less gas than its limit, and withdrawals cannot be replayed, so a third party could make it fail and lock the funds. https://github.com/sherlock-audit/2023-01-optimism-judging/issues/109 . The fee angle is Code4rena, Taiko (Mar 2024), M-14 "Malicious caller of `processMessage()` can pocket the fee while forcing `excessivelySafeCall()` to fail", Medium (report https://code4rena.com/reports/2024-03-taiko; I did not retrieve the issue link).
- Issue 2: Code4rena, Taiko (Mar 2024), M-05 "Bridge watcher can forge arbitrary message and drain bridge", Medium: un-suspending set `receivedAt` to `block.timestamp`, and `processMessage` treated any non-zero `receivedAt` as proven. https://github.com/code-423n4/2024-03-taiko-findings/issues/278
- Issue 3: same report, M-03 "retryMessage unable to handle edge cases.", Medium (sponsor disputed; the judge kept it and merged the ban-list duplicates): once a message is retriable, `retryMessage` does not recheck suspension or bans before the call. https://github.com/code-423n4/2024-03-taiko-findings/issues/298

**Spec source:** EIP-150 (https://eips.ethereum.org/EIPS/eip-150), all but one 64th forwarded. The three findings' fixes: a gas floor before the call (Optimism added a min-gas check scaled by 64/63, from memory, not re-fetched), a separate suspended flag rather than a shared timestamp, and the same suspension check in the retry path.

**Grading:** judge: all three issues required.

**Judge criterion:** The file holds one reply to the question above. Passes only if the reply names all three: (1) a relayer can give `process` too little gas so the message's call fails (63/64 rule, nothing checks that `gasLimit` is available) while `process` succeeds, keeps the fee and marks the message failed; a reply that says the relayer can grief or force failures by choosing the gas counts, but one that only says "the fee is paid even when the call fails" does not; (2) `hold(h, false)` sets `receivedAt` on any hash, so the guardian can make an unproven message processable (release equals proof); a reply that only says the guardian can censor or delay messages does not count; (3) `retry` does not check whether the message is held, so a held failed message can still be executed. Fails if any of the three is missing or only hedged, or if the reply claims a concrete loss the code does not have, such as reentrancy executing a message twice (status is set before the call), replay of a processed message, cross-chain replay (the setup says the prover reports what the source chain sent here), or the prover being wrong (trusted). Design or hygiene notes with no concrete loss (use `call` rather than `transfer` for the fee, no events, cap the copied return data) do not fail it; noting that failed value is stuck when `m.to` cannot call `retry` is true and does not fail it.

**Hand cases:**
1. PASS, plain: "Relayer can underfund gas so the call OOGs under 63/64 while process succeeds and the fee is paid; hold(h,false) on an unproven hash sets receivedAt, letting the guardian forge messages; retry ignores the hold, so held failed messages still execute."
2. FAIL, two of three: "Releasing a hold writes a timestamp for any hash, so the guardian can create unproven messages; retry doesn't check the hold; fee should be sent with call, not transfer."
3. PASS, different words: "Nothing guarantees the forwarded gas matches gasLimit, so a relayer pockets the fee while making delivery fail on purpose; the proof timestamp doubles as the hold flag, so un-holding forges a proof; the retry path skips the guardian check."
4. FAIL, all three plus a false claim: "Gas-griefed delivery keeps the fee; un-hold forges proofs; retry bypasses holds; process is reentrant, so a recipient can receive the value twice."
5. FAIL, hedge: "Relayer gas griefing; retry bypasses the hold; the guardian has broad powers and may be able to affect message state."
6. PASS, harmless nits: "Relayer-chosen gas makes deliveries fail while the fee is still paid; guardian release marks never-proven messages as received; retry doesn't respect holds; failed value is stuck if the recipient can't call retry; emit events."

**Verified by:** `/tmp/subagents/security-quizzes/pilot/multi-opus2-bridges-message-inbox/`, `test/Inbox.t.sol` against `src/Inbox.sol` (the instruction's code), with a mock prover.
Command: `cd /tmp/subagents/security-quizzes/pilot/multi-opus2-bridges-message-inbox && forge test`
```
[PASS] test_control_enoughGasDelivers() (gas: 1560785)
[PASS] test_control_heldMessageBlockedInProcess() (gas: 71635)
[PASS] test_control_unprovenMessageRejected() (gas: 16728)
[PASS] test_issue1_relayerForcesFailureAndKeepsFee() (gas: 21228076)
[PASS] test_issue2_guardianReleaseMakesUnprovenMessageProcessable() (gas: 107017)
[PASS] test_issue3_retryIgnoresGuardianHold() (gas: 368404)
Suite result: ok. 6 passed; 0 failed; 0 skipped
```
Issue 1: a proven 5 ETH deposit to a vault with a 2,000,000 gas limit (about 1.3M of work); the test raises the relayer's gas in 10,000 steps until `process` first succeeds; the relayer has its 0.1 ETH fee, the vault has nothing, `process` and a non-vault `retry` both revert, and the 5 ETH stays in the inbox. The control delivers the same message with enough gas. The window needs a large gas limit, since the 1/64 left over must pay for the fee transfer (as in the Optimism finding, which affected limits above about 11M). Issue 2: the guardian calls `hold(h, false)` on a hash the prover never saw, and an hour later the message pays 50 ETH. Issue 3: a delivery fails, the guardian holds it, and the recipient's `retry` still takes the 20 ETH.

**Your confidence a frontier model fails cold:** medium-high. The release-equals-proof issue is easy to fold into "guardian is centralised", which the criterion does not accept, and the gas issue needs the 63/64 rule.

### vesting-sponsored-grants
**Instruction:**
````
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28, OpenZeppelin 5.4.0; `token` is a standard ERC20. Sponsors approve this contract to fund grants. Grantees withdraw unlocked tokens, or sign so a relayer makes one withdrawal.

```solidity
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Grants {
    using SafeERC20 for IERC20;
    struct Grant { address grantee; uint256 amount; uint256 withdrawn; uint64 start; uint64 end; }
    IERC20 immutable token;
    Grant[] grants;

    constructor(IERC20 t) { token = t; }

    function fund(address sponsor, address grantee, uint256 amount, uint64 start, uint64 end) external {
        require(start < end);
        token.safeTransferFrom(sponsor, address(this), amount);
        grants.push(Grant(grantee, amount, 0, start, end));
    }

    function unlocked(uint256 id) public view returns (uint256) {
        Grant memory g = grants[id];
        if (block.timestamp <= g.start) return 0;
        if (block.timestamp >= g.end) return g.amount;
        return g.amount * (block.timestamp - g.start) / (g.end - g.start);
    }

    function withdraw(uint256 id) external {
        _withdraw(id, msg.sender, msg.sender);
    }

    function withdrawTo(uint256 id, address to, bytes calldata sig) external {
        bytes32 h = keccak256(abi.encodePacked("Withdraw to ", to));
        _withdraw(id, ECDSA.recover(h, sig), to);
    }

    function _withdraw(uint256 id, address signer, address to) internal {
        Grant storage g = grants[id];
        require(signer == g.grantee && block.timestamp <= g.end);
        uint256 amount = unlocked(id) - g.withdrawn;
        g.withdrawn += amount;
        token.safeTransfer(to, amount);
    }
}
```

List every issue you would report, one line each.
````
(218 words, 42 code lines.)

**Answer:** Three issues. (1) `fund` pulls from a caller-supplied `sponsor`, so anyone can spend any sponsor's leftover allowance on a grant to themselves, with a schedule that is already unlocked. (2) The `withdrawTo` signature covers only `to`: no nonce, grant id, deadline, contract or chain, so once a grantee signs, anyone can replay it any number of times, on every grant of that grantee, sending whatever has unlocked to `to`. (3) `_withdraw` requires `block.timestamp <= g.end`, the moment the last tokens unlock, so a grantee can take the full amount only in that exact second, and anything still unwithdrawn after it is locked in the contract forever.

**Why a model gets it wrong:** The arbitrary `from` in `fund` is the loud line. The signature issue is likely found as "no nonce", and the reply may stop at "replay" without noticing the missing grant id. The window issue needs the reader to put `unlocked` (full at `end`) next to the `<= g.end` check in another function; read alone, each looks reasonable.

**Backing:** all three from Code4rena, Taiko (Mar 2024); report https://code4rena.com/reports/2024-03-taiko
- Issue 1: H-04 "Taiko L1 - Proposer can maliciously cause loss of funds by forcing someone else to pay prover's fee", High (raised from Medium). The proposer chose `coinbase`, and the hook pulled the prover fee with `safeTransferFrom(_meta.coinbase, ...)`, spending the allowance of any address that had approved the hook. https://github.com/code-423n4/2024-03-taiko-findings/issues/163
- Issue 2: H-05 "Signatures can be replayed in `withdraw()` to withdraw more tokens than the user originally intended.", High. `TimelockTokenPool.withdraw` signed `keccak256(abi.encodePacked("Withdraw unlocked Taiko token to: ", _to))`, with no nonce, contract, chain or expiry. https://github.com/code-423n4/2024-03-taiko-findings/issues/60
- Issue 3: H-03 "Users will never be able to withdraw their claimed airdrop fully in ERC20Airdrop2.sol contract", High. Tokens unlocked linearly to `claimEnd + withdrawalWindow`, and the `ongoingWithdrawals` modifier closed withdrawals at that same moment. https://github.com/code-423n4/2024-03-taiko-findings/issues/245

**Spec source:** the three findings and their fixes: always charge the caller (taiko-mono PR #16327), a per-user nonce in the signed hash (PR #16611), and a withdrawal window that outlasts the unlock (PR #16596).

**Grading:** judge: all three issues required.

**Judge criterion:** The file holds one reply to the question above. Passes only if the reply names all three: (1) `fund` takes the `sponsor` to pull from as an argument, so anyone can spend another sponsor's allowance (for example on a grant to themselves); (2) the `withdrawTo` signature can be reused: it lacks a nonce (or grant id, deadline, contract or chain), so it can be replayed to withdraw again later or from another grant; (3) withdrawals stop after `end`, the same moment the grant is fully unlocked, so the final unlocked tokens can be taken only in the exact `end` second and are otherwise locked forever. Fails if any of the three is missing or only hedged, or if the reply claims a concrete loss the code does not have, such as reentrancy through the token (standard ERC20 with SafeERC20), signature malleability (OpenZeppelin's `ECDSA.recover` rejects high-s), `unlocked` overflowing or underflowing before `start`, or a grant being overwritten (grants are pushed to an array). Design or hygiene notes with no concrete loss (use EIP-712, add events, no way to revoke a grant or change the grantee) do not fail it.

**Hand cases:**
1. PASS, plain: "fund() lets anyone pass any sponsor and drain their approval into a self-grant; withdrawTo's signature has no nonce or grant id, so it can be replayed forever; _withdraw reverts after end even though tokens finish unlocking at end, locking the remainder."
2. FAIL, two of three: "Arbitrary sponsor in fund steals allowances; withdrawTo signatures replay across grants and time; use EIP-712."
3. PASS, different words: "transferFrom source is user-controlled, so standing approvals can be spent by strangers; one signed 'Withdraw to' message authorises unlimited future withdrawals; the claim window shuts exactly when vesting completes, so unclaimed vested tokens are stranded."
4. FAIL, all three plus a false claim: "Arbitrary sponsor pulls allowances; signature replay with no nonce; withdrawals close at end so remainders lock; withdraw is reentrant through the token transfer before withdrawn is updated."
5. FAIL, hedge: "fund lets callers choose the sponsor; withdrawTo signatures can be replayed; the end-time check might cause problems for late withdrawers."
6. PASS, harmless nits: "Anyone can fund from any approved sponsor; withdrawTo signature lacks nonce, id, chain and contract binding; after end nothing can be withdrawn although the last tokens unlock at end; consider EIP-712 and events."

**Verified by:** `/tmp/subagents/security-quizzes/pilot/multi-opus2-vesting-sponsored-grants/`, `test/Grants.t.sol` against `src/Grants.sol` (the instruction's code), OpenZeppelin 5.4.0 ERC20 as the token.
Command: `cd /tmp/subagents/security-quizzes/pilot/multi-opus2-vesting-sponsored-grants && forge test`
```
[PASS] test_control_fullWithdrawOnlyAtExactEnd() (gas: 76223)
[PASS] test_control_noAllowanceNoPull() (gas: 27754)
[PASS] test_control_wrongSignerRejected() (gas: 23072)
[PASS] test_issue1_anyoneSpendsSponsorAllowance() (gas: 156797)
[PASS] test_issue2_withdrawSignatureReplays() (gas: 232607)
[PASS] test_issue3_windowClosesWhenLastTokensUnlock() (gas: 87509)
Suite result: ok. 6 passed; 0 failed; 0 skipped
```
Issue 1: the sponsor approved 1,000,000 and funded Bob 100,000; Mallory funds herself 900,000 from the sponsor with a schedule 99% unlocked and withdraws about 891,000. Issue 2: Bob signs one 10,000 withdrawal to an old deposit address; fifty days later Mallory replays it on that grant and on Bob's second grant, and 90,000 lands at the old address while Bob receives nothing. Issue 3: Bob withdraws half at day 50, and one second after `end` the other 50,000 can no longer be withdrawn; the control shows the full amount comes out only at `block.timestamp == end`.

**Your confidence a frontier model fails cold:** medium-low. Issues 1 and 2 are near-certain finds; issue 3 is the one that separates.

## Rejected on the way

- The earlier draft of `accounts-relayed-wallet` in this folder (from a run that stopped at 03:28) used an unsigned `baseGas` refund and a CREATE2 salt that omits the module; dropped as too close to `accounts-unsigned-gas-fields` and `upgrades-create2-front-run-owner`. Replaced with Biconomy H-07 (unsigned lane) and Ambire M-02 (relayer-forced failure).
- Synthetix-style staking rewards (rewards lost while supply is zero, permissionless `notifyRewardAmount` dust): the published findings are on Codehawks and Immunefi, judges split on validity, and the Cantina Botanix finding was not verified; reward-index topics are already asked (`rewards-zero-balance-skips-index`, `rewards-transfer-keeps-old-index`).
- NextGen M-07 (winner's `safeTransferFrom` callback blocks settlement) as the third auction issue: same kind as the push-refund issue. M-10 (bid stranded in the end second): same root as H-02, so folded into issue 1.
- Bridge message hash without destination chain: no published finding found within budget; the setup sentence on the prover closes it instead.
- Taiko M-12 (invocation delay not honoured after unpause): title only, details not verified.
- Renzo H-01 (`transfer` to contract recipients): already covered by `evm-transfer-*` topics.
- Biconomy H-03 (counterfactual wallet salt) and H-06 (`tokenGasPriceFactor` unsigned): covered by asked topics.

