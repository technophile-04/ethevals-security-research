# Security Concepts candidates

Ten research drafts for one-sentence answers checked by an LLM judge. Four refine candidates from `pilot-judge.md`.
The incidents and disclosures below support the mechanisms; the questions use simplified code or stated assumptions.
No model trials, Foundry work, judge hand cases, or task implementation ran in this pass.

Each candidate has one binary judge criterion. Accept any correct wording and extra correct detail.
Reject contradictions, guesses between competing causes, and added false causal claims.

Start with **1, 2, and 5** for practical value: batch validation, inherited entry points, and external nonce state.
Candidate **6** also addresses a useful distinction between token approval and signed application consent.
These recommendations reflect the mechanisms, not measured model difficulty.

## 1. An unknown batch action erases the health check

Question:

You are an expert security researcher and smart contract auditor.

This lending market uses Solidity 0.8.28 and a plain ERC-20 without callbacks; `_borrow` pays the borrower.

```solidity
struct Flags { bool checkHealth; }
function run(uint8[] calldata ops) external {
    Flags memory f;
    for (uint256 i; i < ops.length; ++i) {
        if (ops[i] == BORROW) {
            _borrow(msg.sender, 100);
            f.checkHealth = true;
        } else f = _extra(ops[i], f);
    }
    if (f.checkHealth) require(_healthy(msg.sender));
}
function _extra(uint8, Flags memory)
    internal virtual returns (Flags memory) {}
```

How can an account without collateral receive a loan through this batch? Answer in one sentence.

Expected answer: A borrow followed by an unknown action replaces `f` with the empty hook's zeroed return, clears `checkHealth`, and skips the final health check.

Judge criterion: Pass iff the answer identifies the unknown action's zeroed return overwriting the flag after borrowing and thereby skipping the health check.

Backing: [Abracadabra Money incident, October 2025, Verichains analysis](https://blog.verichains.io/p/abracadabra-money-hack-analysis). An undefined action after borrowing reset the pending solvency-check flag in the same way.

## 2. A vault override leaves inherited minting unpaid

Question:

You are an expert security researcher and smart contract auditor.

This WETH vault inherits OpenZeppelin Contracts 5.4 ERC4626; its public `mint` remains unchanged.

```solidity
function deposit(uint256 assets, address receiver)
    public override returns (uint256 shares)
{
    shares = previewDeposit(assets);
    IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
    _deposit(msg.sender, receiver, assets, shares);
}
function _deposit(address, address receiver, uint256 assets, uint256 shares)
    internal override
{
    require(assets >= MIN_DEPOSIT);
    _mint(receiver, shares);
}
```

Assume ordinary share accounting and no token callbacks; identify the path that issues shares without collecting WETH. Answer in one sentence.

Expected answer: The inherited `mint` calls the overridden `_deposit`, which no longer collects WETH, so callers can mint shares without paying assets.

Judge criterion: Pass iff the answer identifies inherited `mint` reaching the overridden `_deposit` without an asset transfer and issuing unpaid shares.

Backing: [Meta Pool mpETH incident, June 2025, Verichains analysis](https://blog.verichains.io/p/free-minting-from-meta-pool-ethereum). Its inherited mint path omitted asset collection after developers changed the shared deposit hook.

## 3. An upgrade skips the migration that sets quorum

Question:

You are an expert security researcher and smart contract auditor.

A proxy using OpenZeppelin Upgradeable 5.4 has initialized through version 2; its new `totalWeight` slot is zero.

```solidity
function initializeV3() external reinitializer(3) {
    totalWeight = manager.totalWeight();
}
function initializeV4(address w) external reinitializer(4) {
    weth = w;
}
function withdraw(Receipt calldata r, Sig[] calldata sigs) external {
    require(verifiedWeight(r, sigs) * 10 >= totalWeight * 7);
    _release(r);
}
```

The atomic upgrade calls only `initializeV4`; the manager's weight is positive, and empty signatures contribute zero weight.
Other receipt checks work. What authorization failure does this upgrade introduce? Answer in one sentence.

Expected answer: Calling version 4 skips version 3, leaves `totalWeight` zero, and lets withdrawals pass the quorum check with no signatures.

Judge criterion: Pass iff the answer connects the skipped version 3 initializer to zero total weight and withdrawals passing without operator signatures.

Backing: [Ronin Bridge incident, August 2024, Beosin analysis](https://beosin.com/resources/the-root-cause-of-ronin-bridges-abnormal-activities). The upgrade skipped the initializer that populated operator weight, leaving the required vote weight zero.

Library rule: [OpenZeppelin 5.4 Initializable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v5.4.0/contracts/proxy/utils/Initializable.sol) permits version jumps without executing skipped reinitializers.

## 4. Cancelling a campaign leaves its spending approval alive

Question:

You are an expert security researcher and smart contract auditor.

An airdrop contract pools one plain ERC-20 across campaigns.
Creating a campaign collects its deposit and grants an equal allowance to a locker chosen by its manager.
Cancellation checks the manager, deletes the campaign, and refunds its full unclaimed deposit.
Cancellation never changes the token allowance.
Assume no claims occurred and refunds cannot reenter.
A manager creates and cancels a campaign using a locker they control.
What right over other campaigns' pooled tokens survives the refund? Answer in one sentence.

Expected answer: The manager's locker retains its allowance and can use `transferFrom` to take other campaigns' tokens after the manager receives the refund.

Judge criterion: Pass iff the answer says the chosen locker's allowance survives cancellation and permits spending other campaigns' pooled tokens after the refund.

Backing: [Hedgey Finance incident, April 2024, CertiK analysis](https://www.certik.com/blog/hedgey-finance-incident-analysis). Cancellation returned the deposit while leaving the creator-controlled locker's token approval usable.

## 5. A router call makes its Permit2 nonce impossible to advance

Question:

You are an expert security researcher and smart contract auditor.

A router caches Permit2 AllowanceTransfer nonces per token and spender.
Each swap submits the cached nonce and increments it only if the swap succeeds; failed swaps revert all changes.
Permit2 requires an exact nonce match.
A separate route uses direct ERC-20 approvals and lets callers choose any external target and calldata, called as the router.
Permit2's `invalidateNonces(token, spender, newNonce)` advances the caller's nonce.
What call through that route can leave later Permit2 swaps for a pair unable to progress? Answer in one sentence.

Expected answer: Calling Permit2's `invalidateNonces` as the router can advance its external nonce beyond the cache, so subsequent swaps revert before any cached increment persists.

Judge criterion: Pass iff the answer identifies router-origin nonce invalidation advancing Permit2 beyond the cache and failed swaps preventing the cache from catching up.

Backing: [Across Permit2 denial-of-service disclosure, OpenZeppelin's Notorious Bug Digest #4](https://www.openzeppelin.com/news/notorious-bug-digest-4). Arbitrary router calls could desynchronize external nonces from local state that only successful swaps advanced.

## 6. A fresh token approval revives an old bridge instruction

Question:

You are an expert security researcher and smart contract auditor.

A bridge wrapper verifies an EIP-712 instruction binding the owner, token, amount, destination, and deadline.
It then pulls tokens using the owner's ERC-20 allowance; it can use an existing allowance.
It records no consumed instruction digest or application nonce.
Alice's instruction to bridge 100 tokens has executed once and remains within its deadline.
Later, Alice signs a fresh ERC-2612 permit approving 500 tokens for a different intended deposit.
A relayer submits that new permit directly to the token.
What can the relayer do with Alice's old bridge signature despite ERC-2612 nonce protection? Answer in one sentence.

Expected answer: The relayer can replay the old bridge instruction against the fresh allowance because the token permit's nonce does not consume the separate application signature.

Judge criterion: Pass iff the answer identifies replaying the old bridge instruction using the replenished allowance despite the token permit's separate nonce protection.

Backing: [Across Periphery Changes Audit, "Possible Replay Attacks on SpokePoolPeriphery," OpenZeppelin](https://www.openzeppelin.com/news/periphery-changes-audit). A later token approval could fund an earlier signed deposit instruction that lacked its own replay protection.

## 7. A batch authorizes itself before its final check

Question:

You are an expert security researcher and smart contract auditor.

A timelock administers itself; its own calls can change the minimum delay or grant proposer rights.
Proposers schedule batches, and a zero-delay batch becomes ready immediately.

```solidity
function executeBatch(Call[] calldata calls) external onlyExecutor {
    bytes32 id = hash(calls);
    for (uint256 i; i < calls.length; ++i) _call(calls[i]);
    require(isReady(id));
    done[id] = true;
}
```

Calls can target the timelock or a helper that knows the full batch.
How can an executor without proposer rights execute a previously unscheduled batch? Answer in one sentence.

Expected answer: The batch can lower the delay, grant a helper proposer rights, and have it schedule that same batch before the final readiness check.

Judge criterion: Pass iff the answer explains using batch self-calls to lower the delay and grant proposer rights, then scheduling itself before the postcheck.

Backing: [OpenZeppelin TimelockController vulnerability disclosure, September 2021](https://forum.openzeppelin.com/t/timelockcontroller-vulnerability-post-mortem/14958/2). Checking readiness after execution let an unscheduled batch grant authority and schedule itself with zero delay.

## 8. Correct deposit calldata does not secure withdrawal credentials

Question:

You are an expert security researcher and smart contract auditor.

A staking pool accepts validator public keys from node operators.
It checks that its 32 ETH deposit data names the pool's withdrawal credentials and carries a valid validator signature.
Ethereum records credentials on a public key's first valid deposit; later deposits to that key add balance without replacing them.
The pool does not check for earlier deposits.
An operator sees the pool's pending deposit for a previously unused key they control.
How can the operator redirect control of the pool's stake despite its calldata check? Answer in one sentence.

Expected answer: The operator can first deposit 1 ETH for the same key with their own withdrawal credentials, causing the pool's later deposit to fund that validator.

Judge criterion: Pass iff the answer identifies a prior deposit for the same key fixing operator-controlled credentials that the pool's later deposit cannot replace.

Backing: [Lido deposit front-running disclosure, October 2021](https://research.lido.fi/t/mitigations-for-deposit-front-running-vulnerability/1239). An operator's 1 ETH predeposit could fix its own credentials before the pool supplied the validator's main stake.

## 9. A new router entry point spends old wallet approvals

Question:

You are an expert security researcher and smart contract auditor.

Users have approved a router to spend their standard ERC-20 tokens.
Its existing routes restrict external targets and function selectors; a new public route does this without those restrictions:

```solidity
function route(address target, bytes calldata data) external {
    (bool ok,) = target.call(data);
    require(ok);
}
```

It neither authenticates a token owner nor limits calldata to the caller's funds.
What call can move an approved user's tokens even when that user never invokes this route? Answer in one sentence.

Expected answer: Anyone can target the token with `transferFrom(victim, recipient, amount)`, which executes as the approved router and spends the victim's allowance.

Judge criterion: Pass iff the answer identifies calling the token's `transferFrom` through the router so its existing victim allowance authorizes the transfer.

Backing: [LI.FI security incident report, July 2024](https://li.fi/knowledge-hub/incident-report-16th-july). A new facet omitted target and function validation, exposing users' existing token approvals to arbitrary contract calls.

## 10. An approved zero root authenticates messages never proved

Question:

You are an expert security researcher and smart contract auditor.

This simplified bridge stores a proved message's root in `messageRoot`; untouched entries default to zero.
An upgrade initializes `confirmedAt[bytes32(0)] = 1`.

```solidity
function process(bytes calldata message) external {
    bytes32 h = keccak256(message);
    require(!processed[h]);
    uint256 t = confirmedAt[messageRoot[h]];
    require(t != 0 && block.timestamp >= t);
    processed[h] = true;
    _deliver(message);
}
```

`_deliver` checks message format, not origin; the current timestamp exceeds 1.
Why can a well-formed message pass without anyone proving it? Answer in one sentence.

Expected answer: An unproved message reads the default zero root, which the upgrade marked confirmed, so the confirmation check accepts it as authenticated.

Judge criterion: Pass iff the answer connects the unproved message's default zero root to the accepted zero-root entry and resulting false authentication.

Backing: [Nomad Bridge incident, August 2022, Halborn analysis](https://www.halborn.com/blog/post/explained-the-nomad-hack-august-2022). Accepting the zero root caused messages with default, unproved root entries to pass validation.

## Limits and exclusions

These are candidate ideas, not implemented tasks. Their snippets express the named mechanism without reproducing each incident's full contracts.
The source checks establish incident backing; they do not replace a later code proof or judge review.
Model difficulty remains unknown for all ten.

Candidates 4, 9, and 10 have direct explanations and are reserves if trials show they add little value.
Candidate 3 shares initializer vocabulary with an excluded question, but asks about skipped migrations and zero quorum rather than constructor initialization.
Candidates 5 and 6 use different nonce mechanisms: external state desynchronization and replay of a separate application signature.

I omitted the pilot's transient-slot example because it depends on matching a minted amount to a controlled address.
I also omitted Safe delegatecall questions, compiler-specific puzzles, and mechanisms already listed in `asked-slugs.txt` or `pilot-opus.md`.
