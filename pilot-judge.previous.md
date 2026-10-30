# Round three: judge-graded root-cause questions

Work in progress. Each candidate rests on a real incident or disclosure, opens with the auditor line, asks one root-cause question, and ends "Answer in one sentence." Code questions are proved by a Foundry test under `/tmp/subagents/security-quizzes/pilot/<slug>/`; design questions cite the post-mortem line and the code that fixes the answer. No model trials have run, so every confidence line is a guess.

---

### lending-batch-status-reset
**Instruction:**
You are an expert security researcher and smart contract auditor.

This lending market batches user actions. Solidity 0.8.28; the borrowed token is a plain ERC-20.

```solidity
struct Flags { bool checkHealth; }

function run(uint8[] calldata ops, bytes[] calldata args) external {
    Flags memory f;
    for (uint256 i; i < ops.length; i++) {
        if (ops[i] == DEPOSIT) _deposit(msg.sender, abi.decode(args[i], (uint256)));
        else if (ops[i] == BORROW) { _borrow(msg.sender, abi.decode(args[i], (uint256))); f.checkHealth = true; }
        else if (ops[i] == REPAY) _repay(msg.sender, abi.decode(args[i], (uint256)));
        else f = _customOp(ops[i], f, args[i]);
    }
    if (f.checkHealth) require(_healthy(msg.sender), "unhealthy");
}

function _customOp(uint8, Flags memory, bytes calldata) internal virtual returns (Flags memory) {}
```

Accounts that had posted no collateral walked away with borrowed tokens. What is the root cause? Answer in one sentence.

**Answer:** The catch-all branch assigns `_customOp`'s return value to `f`, and the empty default returns a zeroed `Flags`, so a borrow followed by any op the market doesn't handle clears `checkHealth` and the health check never runs.

**Why a model gets it wrong:** The guard looks complete: every borrow schedules a health check at the end of the batch. The reset hides in a branch that reads as an extension hook, and an empty `{}` body reads as "does nothing" rather than "returns an all-false struct". A reader who stops at the shape blames `_borrow` paying out before the check, which a plain ERC-20 with no hooks rules out.

**Backing:** Abracadabra, 4 October 2025, about 1.79M MIM (about $1.7M) from six deprecated CauldronV4 markets. The attacker called `cook()` with actions `[5, 0]`: action 5 is the borrow, action 0 is undefined and fell through to the empty `_additionalCookAction`, which returned an all-false `CookStatus` and cleared `needsSolvencyCheck`. Verichains: https://blog.verichains.io/p/abracadabra-money-hack-analysis ; Rekt: https://rekt.news/abracadabra-rekt3 ; QuillAudits: https://www.quillaudits.com/blog/hack-analysis/abracadabra-hack-explained . I found no post-mortem from the Abracadabra team itself. The snippet renames the struct, the function and the actions.

**Spec source:** Solidity semantics: a function with unnamed return parameters and an empty body returns zero-initialised values. Proved by execution below.

**Grading:** judge: criterion `custom_op_clears_health_flag`

**Judge criterion:** Passes if the reply says the else branch overwrites `f` with what `_customOp` returns, and the empty default returns a zeroed `Flags`, so an unhandled op after a borrow clears `checkHealth` and the health check is skipped; fails if it blames reentrancy, `_borrow`, `_healthy`, the check running only once at the end, or hedges between causes.

**Hand cases:**
- pass: "The else branch overwrites `f` with `_customOp`'s return, and the empty default returns a zeroed Flags, so BORROW followed by any unhandled op clears checkHealth and the final health check is skipped."
- pass: "`f = _customOp(...)` resets `checkHealth` to false because the default implementation returns an empty struct, so a batch of [BORROW, 0] borrows with no health check."
- pass (other words): "Any action number the market doesn't recognise replaces the pending flags with the hook's all-false default, wiping the solvency check that the borrow had scheduled."
- fail (hedge): "Either the empty `_customOp` wipes the health flag or `_borrow` pays out before the check and lets the borrower re-enter; one of the two lets uncollateralised borrows through."
- fail (near miss): "The health check runs once at the end of the batch instead of after each borrow, so a user can borrow and move the tokens out before it is evaluated."
- fail (confident wrong): "`_borrow` transfers the tokens before the health check, so the borrower re-enters `run` from the token callback and borrows again before the first check runs."

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/lending-batch-status-reset && forge test` (solc 0.8.28, optimizer on, legacy pipeline, Cancun) → `[PASS] testBorrowThenUnknownOpSkipsHealthCheck()` (no collateral, ops `[BORROW, 0]`, user holds 100,000 borrowed tokens), with controls `[PASS] testBorrowAloneReverts()` and `[PASS] testUnknownOpBeforeBorrowStillChecked()`.

**Your confidence a frontier model fails cold:** medium

---

### upgrades-skipped-reinitializer
**Instruction:**
You are an expert security researcher and smart contract auditor.

This bridge is a UUPS proxy on OpenZeppelin Contracts Upgradeable 5.4 that has already run `initialize` and `initializeV2`. Operator weights live in `manager`.

```solidity
uint256 private totalWeightCache;

function initializeV3() external reinitializer(3) {
    totalWeightCache = manager.totalWeight();
}

function initializeV4(address newWeth) external reinitializer(4) {
    weth = newWeth;
}

function withdraw(Receipt calldata r, Sig[] calldata sigs) external {
    uint256 signed = _sumVerifiedWeight(keccak256(abi.encode(r)), sigs); // sorted, verified signers
    require(signed * 10 >= totalWeightCache * 7, "quorum");
    _release(r);
}
```

The team upgrades with `upgradeToAndCall(newImpl, abi.encodeCall(Bridge.initializeV4, (weth)))`. What should the reviewer flag? Answer in one sentence.

**Answer:** `initializeV3` never runs, because `reinitializer(4)` moves the version straight from 2 to 4 (and `reinitializer(3)` reverts from then on), so `totalWeightCache` stays 0 and `withdraw` passes its quorum check with no operator signatures at all.

**Why a model gets it wrong:** Numbered reinitializers read like a migration chain that must run in order, so a reader either assumes version 4 requires version 3 (and the call would revert) or flags the visible decoy instead: neither initializer has access control. That decoy isn't live, since `upgradeToAndCall` runs `initializeV4` atomically and leaves both initializers locked.

**Backing:** Ronin Bridge, 6 August 2024, about $12M (about 4,000 ETH and 2M USDC) withdrawn by MEV bots and returned as a white-hat recovery. The upgrade script called only `initializeV4`; `initializeV3`, which set `_totalOperatorWeight`, never ran, so the minimum vote weight was zero. Halborn: https://www.halborn.com/blog/post/explained-the-ronin-network-hack-august-2024 ; Verichains via Cointelegraph: https://cointelegraph.com/news/ronin-bridge-hack-upgrade-script-verichains . Sources differ on whether V3 and V4 were both added in that one upgrade; the snippet doesn't depend on it.

**Spec source:** OpenZeppelin Contracts Upgradeable 5.4, `proxy/utils/Initializable.sol` lines 145-146: "Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in a contract, executing them in the right order is up to the developer or operator."

**Grading:** judge: criterion `v3_skipped_zero_quorum`

**Judge criterion:** Passes if the reply says `initializeV3` never runs, so `totalWeightCache` stays 0 and `withdraw` accepts receipts without the operator weight it should need; fails if it flags something else as the problem (missing access control on the initializers, front-running, the signature loop), says the `initializeV4` call reverts, or hedges between causes. A reply may add that `initializeV3` can't run later or suggest a fix.

**Hand cases:**
- pass: "Only initializeV4 runs, so initializeV3 is skipped, totalWeightCache stays 0, and withdraw's quorum check passes even with zero signatures."
- pass: "reinitializer(4) jumps the version from 2 to 4 without ever executing initializeV3, leaving the cached total weight at zero, so anyone can withdraw with an empty signature list."
- pass (other words): "The weight snapshot is set only in the V3 initializer, which this upgrade never calls, so the threshold becomes 0 × 7 and every receipt clears quorum."
- fail (hedge): "Either initializeV3 is skipped and the quorum is zero, or anyone can call the unprotected initializeV3 afterwards and set their own weights."
- fail (near miss): "initializeV3 and initializeV4 have no access control, so after the upgrade anyone can call initializeV3 and overwrite the weight cache."
- fail (confident wrong): "The upgrade reverts, because reinitializer(4) requires the contract to be on version 3 first, so the bridge stays on the old implementation."

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/upgrades-skipped-reinitializer && forge test` (solc 0.8.28, OpenZeppelin Contracts Upgradeable 5.4.0, ERC1967Proxy) → `[PASS] testUpgradeSkipsV3AndQuorumIsZero()` (version is 4, cache is 0, a receipt with no signatures pays out 4,000 ETH), `[PASS] testInitializeV3CanNeverRunAfterwards()` (reverts `InvalidInitialization()`), control `[PASS] testWithV3TheEmptyReceiptFails()` (reverts "quorum").

**Your confidence a frontier model fails cold:** medium

---

### vaults-inherited-mint-path
**Instruction:**
You are an expert security researcher and smart contract auditor.

This staking vault extends OpenZeppelin Contracts 5.4 `ERC4626`; the asset is WETH.

```solidity
function depositETH(address receiver) external payable returns (uint256 shares) {
    shares = previewDeposit(msg.value);
    IWETH(asset()).deposit{value: msg.value}();
    _deposit(msg.sender, receiver, msg.value, shares);
}

function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
    shares = previewDeposit(assets);
    IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
    _deposit(msg.sender, receiver, assets, shares);
}

function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
    require(assets >= MIN_DEPOSIT, "too small");
    _mint(receiver, shares);
    emit Deposit(caller, receiver, assets, shares);
}
```

Soon after launch, the vault's shares were backed by far less WETH than they should be. What is the root cause? Answer in one sentence.

**Answer:** The inherited public `mint(shares, receiver)` still calls the overridden `_deposit`, which no longer pulls the asset (OpenZeppelin's base `_deposit` is where the `safeTransferFrom` lives), so anyone can mint shares without paying any WETH.

**Why a model gets it wrong:** Both visible entry points collect the asset correctly, so a reader checks them, finds them sound, and reaches for the usual ERC-4626 suspects: first-depositor inflation, rounding direction, or `previewDeposit` running before the wrap. The bug sits in a function the snippet doesn't show, and spotting it needs the reader to remember that `mint` is a second public path into `_deposit`.

**Backing:** Meta Pool mpETH, 17 June 2025. The attacker minted about 9,700 mpETH for free and realised about 52 to 56 ETH (about $132K to $142K) from thin pools; reported nominal value about $27M. OpenZeppelin's Notorious Bug Digest #4: mpETH "overrode `deposit` and `_deposit`, moving the receipt check out of `_deposit` and into `deposit`. The public `mint` function still called the overridden `_deposit`" https://www.openzeppelin.com/news/notorious-bug-digest-4 ; Verichains: https://blog.verichains.io/p/free-minting-from-meta-pool-ethereum ; Cointelegraph: https://cointelegraph.com/news/meta-pool-exploiter-flees-132k-in-27-million-hack

**Spec source:** OpenZeppelin Contracts 5.4.0 `token/ERC20/extensions/ERC4626.sol`: `mint` (line 184) computes `previewMint(shares)` and calls `_deposit`; the base `_deposit` (line 239) does `SafeERC20.safeTransferFrom(IERC20(asset()), caller, address(this), assets)` at line 247.

**Grading:** judge: criterion `inherited_mint_skips_transfer`

**Judge criterion:** Passes if the reply says the inherited `mint` function still reaches the overridden `_deposit`, which no longer transfers the asset in, so shares are minted without WETH being paid; fails if it blames share inflation or donations, rounding, the order of `previewDeposit` and the wrap in `depositETH`, the minimum-deposit check, or hedges between causes.

**Hand cases:**
- pass: "The inherited ERC4626 mint() calls the overridden _deposit, which only mints shares and never pulls WETH, so anyone can mint shares for free."
- pass: "Overriding _deposit removed OpenZeppelin's safeTransferFrom, and only deposit and depositETH collect assets themselves, so mint(shares, receiver) issues shares with no WETH."
- pass (other words): "The shares-denominated entry point that ERC-4626 also exposes still routes into the custom `_deposit`, and since that hook no longer takes the caller's assets, buying shares through it costs nothing."
- fail (hedge): "Either the first depositor inflated the share price with a donation, or mint() reaches _deposit without a transfer; both would leave shares under-backed."
- fail (near miss): "depositETH computes previewDeposit before wrapping the ETH, so the share price is computed on the wrong balance and depositors get too many shares."
- fail (confident wrong): "With no decimals offset, the first depositor can donate WETH and inflate the share price, so later deposits round down and the shares end up under-backed."

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/vaults-inherited-mint-path && forge test` (solc 0.8.28, OpenZeppelin Contracts 5.4.0) → `[PASS] testInheritedMintIsFree()` (Bob holds no ETH or WETH, `mint(1000e18)` gives him 1,000 shares, the vault's WETH stays at 100, and Bob then redeems more than 90 WETH of Alice's), control `[PASS] testDepositPathsCollectAssets()`.

**Your confidence a frontier model fails cold:** medium

---

### approvals-cancel-leaves-allowance
**Instruction:**
You are an expert security researcher and smart contract auditor.

This claims contract holds the tokens of every airdrop campaign. Solidity 0.8.28 with OpenZeppelin 5.4 `SafeERC20` and `ReentrancyGuard`.

```solidity
function createCampaign(bytes16 id, IERC20 token, uint256 amount, address locker, bytes32 root) external {
    require(campaigns[id].manager == address(0), "exists");
    token.safeTransferFrom(msg.sender, address(this), amount);
    token.safeIncreaseAllowance(locker, amount);
    campaigns[id] = Campaign(msg.sender, token, amount, locker, root);
}

function cancelCampaign(bytes16 id) external nonReentrant {
    Campaign memory c = campaigns[id];
    require(msg.sender == c.manager, "not manager");
    delete campaigns[id];
    c.token.safeTransfer(c.manager, c.amount);
}
```

One manager created and cancelled a large campaign in a single transaction. Shortly after, the contract's whole balance of that token was gone. What is the root cause? Answer in one sentence.

**Answer:** `cancelCampaign` refunds the deposit but never revokes the allowance that `createCampaign` granted to the manager-chosen `locker`, so the manager's own contract later calls `transferFrom` and takes the same amount again out of other campaigns' tokens.

**Why a model gets it wrong:** The cancel path looks textbook: authorisation check, delete before transfer, `nonReentrant`. "Created and cancelled in one transaction" points at a flash loan or reentrancy, and the loss shows up later, through a function the contract never calls itself. The allowance lives in the token's storage, not in `campaigns`, so deleting the campaign reads as a full clean-up.

**Backing:** Hedgey Finance, 19 April 2024. The attacker created a locked campaign with a flash-loaned deposit and their own contract as `tokenLocker`, cancelled it in the same transaction, then used the lingering allowance to pull the contract's tokens. About $2M on Ethereum per CertiK; the widely quoted $44.7M values BONUS tokens on Arbitrum at a price their liquidity couldn't support. CertiK: https://www.certik.com/resources/blog/hedgey-finance-incident-analysis ; Verichains: https://blog.verichains.io/p/approval-error-vulnerability-analyzing ; Halborn: https://halborn.com/blog/post/explained-the-hedgey-finance-hack-april-2024

**Spec source:** ERC-20 (https://eips.ethereum.org/EIPS/eip-20): an allowance persists in the token contract until spent or changed; nothing in `cancelCampaign` changes it. Proved by execution below.

**Grading:** judge: criterion `cancel_keeps_locker_allowance`

**Judge criterion:** Passes if the reply says cancelling refunds the tokens but leaves the allowance granted to the creator-chosen `locker` in place, so that address can later pull the same amount from the tokens other campaigns deposited; fails if it blames reentrancy, a flash loan by itself, a missing check on `root` or on claims, the campaign id being reusable, or hedges between causes.

**Hand cases:**
- pass: "cancelCampaign returns the tokens to the manager but never resets the allowance given to the locker, which the manager chose, so the locker can transferFrom the same amount out of everyone else's campaigns."
- pass: "The approval to the user-supplied locker survives cancellation, so the manager gets refunded and keeps a live allowance over the pooled tokens."
- pass (other words): "Deleting the campaign doesn't undo the `safeIncreaseAllowance` on the token, so the creator's chosen spender can still move that amount from the shared balance after the refund, effectively getting paid twice."
- fail (hedge): "Either the leftover allowance to the locker or a reentrant call during the refund let the manager take the pooled tokens."
- fail (near miss): "The locker address isn't validated, so a malicious locker can claim the campaign's tokens through the claim path without a valid Merkle proof."
- fail (confident wrong): "cancelCampaign transfers c.amount without checking how much was already claimed, so the manager is refunded tokens that users had already received."

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/approvals-cancel-leaves-allowance && forge test` (solc 0.8.28, OpenZeppelin Contracts 5.4.0) → `[PASS] testCancelLeavesAllowanceToCreatorChosenLocker()` (after create and cancel, the manager is refunded 1,000,000, the locker's allowance is still 1,000,000, and the locker then pulls the honest campaign's 1,000,000, leaving the contract empty).

**Your confidence a frontier model fails cold:** medium-low

---

### callbacks-transient-slot-reuse
**Instruction:**
You are an expert security researcher and smart contract auditor.

This vault (Solidity 0.8.28, Cancun) swaps a user's WETH through a Uniswap v3 pool and mints leveraged tokens against the output.

```solidity
function mint(IUniswapV3Pool pool, uint256 debtIn) external returns (uint256 minted) {
    require(isVaultPool[address(pool)], "pool");
    weth.safeTransferFrom(msg.sender, address(this), debtIn);
    assembly { tstore(1, pool) }
    pool.swap(address(this), true, int256(debtIn), PRICE_LIMIT, abi.encode(msg.sender));
    assembly { minted := tload(1) }
}

function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) external {
    address pool;
    assembly { pool := tload(1) }
    require(msg.sender == pool, "caller");
    uint256 minted = _mintLeveraged(abi.decode(data, (address)), uint256(-amount1));
    assembly { tstore(1, minted) }
    weth.safeTransfer(msg.sender, uint256(amount0));
}
```

The vault's whole WETH balance left in one transaction. What is the root cause? Answer in one sentence.

**Answer:** Slot 1 authenticates the callback caller but is overwritten with the minted amount and left set, so for the rest of the transaction any caller whose address equals that number, which the minter steers through `debtIn`, passes the check and is paid `amount0` of WETH.

**Why a model gets it wrong:** The callback guard is the standard one (store the pool before the swap, require `msg.sender` to match), and transient storage reads as automatically safe because it clears at the end of the transaction. The reuse of the same slot as a return channel looks like a gas trick, and the step from "an amount" to "an address someone controls" needs the reader to see that a 160-bit address can equal a token amount.

**Backing:** SIR.trading, 30 March 2025, about $355K, the protocol's whole TVL. The Vault's `uniswapV3SwapCallback` used transient slot 1 for both the pool address and the minted amount; the attacker ground a vanity address equal to the amount (address `0x00000000001271551295307aCC16bA1e7E0d4281`, amount 95759995883742311247042417521410689) and called the callback directly. Rekt: https://rekt.news/sirtrading-rekt ; SolidityScan: https://blog.solidityscan.com/synthetics-implemented-right-sir-hack-analysis-837d328c4c30/ . SlowMist frames the same flaw as a `tstore` value not cleared after the call.

**Spec source:** EIP-1153 (https://eips.ethereum.org/EIPS/eip-1153): transient storage persists across calls for the whole transaction and is cleared only at its end. Proved by execution below.

**Grading:** judge: criterion `minted_amount_becomes_trusted_caller`

**Judge criterion:** Passes if the reply says transient slot 1, used to authenticate the callback caller, is overwritten with the minted amount (and not cleared), so later in the same transaction a caller whose address equals that value passes the `msg.sender` check and receives WETH; fails if it says only that the slot isn't cleared so the pool can call again, or blames reentrancy, missing slippage limits, the unchecked `amount0`, or hedges between causes.

**Hand cases:**
- pass: "After the first callback, slot 1 holds the minted amount instead of the pool, so anyone whose address numerically equals that amount, which the minter can choose via debtIn and a vanity address, can call uniswapV3SwapCallback directly and be paid the vault's WETH."
- pass: "The callback reuses tstore slot 1 for `minted`, so the 'expected pool' becomes a user-controlled number, and a contract deployed at that address passes the caller check later in the transaction."
- pass (other words): "One transient slot does two jobs, caller authentication and returning the mint result, so after mint() the authorised caller is whatever address matches the minted figure, and the minter can arrange to own it."
- fail (hedge): "Either the transient slot keeps a stale value that lets a different caller in, or the missing slippage limit let the pool take the vault's WETH."
- fail (near miss): "Slot 1 isn't cleared after mint(), so the same pool can call uniswapV3SwapCallback again in that transaction and collect WETH a second time."
- fail (confident wrong): "The callback trusts amount0 from the pool and doesn't check it against debtIn, so a manipulated pool reports a huge amount0 and the vault pays it."

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/callbacks-transient-slot-reuse && forge test` (solc 0.8.28, Cancun) → `[PASS] testMintedAmountBecomesTheTrustedCaller()` (a contract etched at SIR's vanity address mints with `debtIn` equal to its own address, then calls the callback in the same transaction and takes the vault's 1,000 WETH), control `[PASS] testDirectCallRejected()`. The mock pool swaps 1:1 and the mock mints one leveraged unit per collateral unit; only the authentication path matters.

**Your confidence a frontier model fails cold:** medium

