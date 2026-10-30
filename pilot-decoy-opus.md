# Decoy root-cause candidates, Opus drafter (brief5)

Six judge-graded candidates on token and callback semantics, access-control paths, gas and stipend behaviour, and encoding.
Each snippet holds a harmless textbook smell (the decoy) and a quieter real cause of loss.
Each has a Foundry project under `/tmp/subagents/security-quizzes/pilot/opus-<slug>/` with a decoy test and a loss test.
The repo stayed read only. No model trials or judge calls ran; confidence lines are predictions.
Pinned for every proof: Solidity 0.8.28, EVM cancun, OpenZeppelin Contracts 5.4.0 from `pilot/deps/oz5` (the 4.9.6 copy in `pilot/deps/oz496` is used only for contrast).

### callbacks-hook-credits-operator
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28; `nft` is an unmodified OpenZeppelin 5.4.0 ERC721. Owners deposit with safeTransferFrom, often through a helper contract they approved for all their NFTs. An owner later finds the NFT gone from the vault and cannot withdraw it.

```solidity
pragma solidity 0.8.28;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NftVault {
    IERC721 public immutable nft;
    mapping(uint256 => address) public depositor;
    constructor(IERC721 n) { nft = n; }

    function onERC721Received(address from, address, uint256 id, bytes calldata)
        external returns (bytes4)
    {
        require(msg.sender == address(nft), "wrong collection");
        depositor[id] = from;
        return this.onERC721Received.selector;
    }

    function withdraw(uint256 id) external {
        require(depositor[id] == msg.sender, "not yours");
        nft.transferFrom(address(this), msg.sender, id);
        delete depositor[id];
    }
}
```

What is the root cause of the loss? Answer in one sentence.

**Answer:** `onERC721Received` stores its first argument, which ERC-721 defines as the operator that called `safeTransferFrom`, as the depositor instead of the second argument (the previous owner), so an NFT deposited through an approved helper is credited to the helper, which can then withdraw it.

**Decoy:** `withdraw` calls out before `delete depositor[id]`, the shape every reentrancy finding flags. It is harmless here: OpenZeppelin 5.4.0 `ERC721.transferFrom` never calls the receiver (only the `safe*` functions do), the hook checks its caller, and nothing else reads `depositor` mid-call.

**Why a model gets it wrong:** The checks-effects-interactions break is the loudest thing in the snippet, and the hook looks careful because it checks `msg.sender`. The real cause needs the reader to know the receiver's parameter order `(operator, from, tokenId, data)` and to see that the code named the operator slot `from`.

**Backing:** Code4rena, Backed Protocol (papr) contest, December 2022, H-03, **High**: "Collateral NFT deposited to a wrong address, when transferred directly to `PaprController`", [finding #183](https://github.com/code-423n4/2022-12-backed-findings/issues/183) (labels: 3 (High Risk), selected for report, sponsor confirmed). The papr hook used the first argument as the owner, so NFTs sent by an approved address or operator were credited to the operator's vault. Contest finding, no live loss claimed.

**Decoy source:** Code4rena, Delegate contest, September 2023, [finding #37](https://github.com/code-423n4/2023-09-delegate-findings/issues/37), "Function TransferFrom is vulnerable to reentrancy which leads to loss of funds", labelled invalid (withdrawn by warden): it claimed reentrancy inside an ERC-721 `transferFrom` that makes no external call.

**Spec source:** [EIP-721](https://eips.ethereum.org/EIPS/eip-721) defines `onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data)`. OpenZeppelin 5.4.0 `ERC721Utils.checkOnERC721Received` calls `onERC721Received(operator, from, tokenId, data)` (`token/ERC721/utils/ERC721Utils.sol` line 33), and `ERC721.transferFrom` (lines 115 to 125) only calls `_update`, with no receiver call.

**Grading:** judge: criterion `hook_credits_operator`

**Judge criterion:** Passes if the reply says the hook records its first argument, the operator or caller of `safeTransferFrom`, instead of the previous owner `from` (the second argument), so a deposit made by an approved helper is credited to the helper; fails if it blames re-entry through `withdraw`'s transfer before the delete, says the hook lacks a caller check, hedges between causes, or names any other cause.

**Hand cases:**
- pass: "onERC721Received records its first parameter, which is the operator that called safeTransferFrom, as the depositor instead of the second parameter `from`, so a deposit made by an approved helper is credited to the helper, which can withdraw it."
- pass: "The hook credits the operator rather than the previous owner, so NFTs deposited by an approved contract belong to that contract in the vault."
- pass: "The vault reads the wrong slot of the receiver callback: ERC-721 passes (operator, from, tokenId, data), and the code calls the operator slot `from`."
- fail, hedge: "Either withdraw's transfer before `delete depositor[id]` lets a contract re-enter, or the hook credits the operator instead of the owner."
- fail, near miss: "onERC721Received does not restrict who calls it, so any contract can call it directly and assign itself any token id."
- fail, confident decoy: "withdraw sends the NFT before deleting depositor[id], breaking checks-effects-interactions, so a contract depositor re-enters withdraw during the transfer and pulls out NFTs that belong to other owners."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/opus-callbacks-hook-credits-operator`, solc 0.8.28, optimizer 200, legacy pipeline, Cancun, OpenZeppelin 5.4.0. The test imports `src/NftVault.sol`, which is the snippet byte for byte.
- `[PASS] test_decoy_transferFromBeforeDeleteCannotReenter()`: a depositor contract whose hook and fallback both try to re-enter `withdraw` gets its own NFT back with zero hook calls and zero fallback calls; Alice's NFT stays in the vault and a second withdraw reverts.
- `[PASS] test_loss_hookCreditsOperatorNotOwner()`: Alice approves a helper, the helper calls `safeTransferFrom(alice, vault, 7)`, `depositor(7)` is the helper, Alice's withdraw reverts with "not yours", and the helper withdraws Alice's NFT.

**Your confidence a frontier model fails cold:** medium. A model that knows the hook's parameter order will pass; one that pattern-matches on the external call before the delete will blame reentrancy.

### encoding-downcast-outside-unchecked
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28; `token` is an unmodified OpenZeppelin 5.4.0 ERC20 with 18 decimals. Savings has paid one saver far more tokens than that saver ever deposited.

```solidity
pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Savings {
    IERC20 public immutable token;
    mapping(address => uint64) public credit;
    constructor(IERC20 t) { token = t; }

    function deposit(uint64 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount));
        credit[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        uint64 c = credit[msg.sender];
        uint64 debit = uint64(amount);
        require(c >= debit, "insufficient");
        unchecked { credit[msg.sender] = c - debit; }
        require(token.transfer(msg.sender, amount));
    }
}
```

What is the root cause of the loss? Answer in one sentence.

**Answer:** The explicit conversion `uint64(amount)` silently drops the high bits (Solidity 0.8 does not check explicit conversions), so `withdraw` checks and debits only the truncated amount while `transfer` pays the full `uint256` amount; withdrawing 2^64 + 1 wei costs 1 wei of credit.

**Decoy:** the `unchecked` subtraction. It cannot wrap: the `require` compares exactly the 64-bit `debit` that is subtracted, so `c - debit` is never negative.

**Why a model gets it wrong:** `unchecked` next to a balance is the textbook 0.8 smell, and models read "0.8 has checked arithmetic" as covering conversions too. The cast sits outside the `unchecked` block, which makes it look like the safe part. Models also tend to treat `uint64` as "big enough", but with 18 decimals it holds only about 18.45 tokens.

**Backing:** Code4rena, Escher contest, December 2022, M-08, **Medium**: "Unsafe downcasting operation truncate user's input", [finding #369](https://github.com/code-423n4/2022-12-escher-findings/issues/369) (labels: 2 (Med Risk), selected for report, sponsor confirmed). In `FixedPrice.buy`, the price check used the full `_amount` while `uint48(_amount)` set how many editions were minted, so the check and the state change disagreed. This snippet keeps that shape (check and debit on the cast value, money moved on the full value) and flips who loses. Contest finding, no live loss claimed. The same pattern, `totalFees + uint64(fee)`, appears as a validated High in Cyfrin's Puppy Raffle (CodeHawks First Flight, October 2023), per search-result snippets of [CodeHawks submissions](https://codehawks.cyfrin.io/c/2023-10-Puppy-Raffle/s/269); not opened.

**Decoy source:** Code4rena, OpenSea Seaport contest, May 2022, [finding #96](https://github.com/code-423n4/2022-05-opensea-seaport-findings/issues/96), "Underflow unchecked", labelled invalid and sponsor disputed: the warden flagged an `unchecked` subtraction in `AmountDeriver`; the sponsor showed an earlier validation (`startTime < endTime`) already rules out the underflow.

**Spec source:** Solidity documentation, [Checked or Unchecked Arithmetic](https://docs.soliditylang.org/en/v0.8.28/control-structures.html#checked-or-unchecked-arithmetic) (explicit type conversions truncate and never fail, except integer to enum) and [Explicit Conversions](https://docs.soliditylang.org/en/v0.8.28/types.html#explicit-conversions) (higher-order bits are cut off).

**Grading:** judge: criterion `cast_truncates_debit`

**Judge criterion:** Passes if the reply says the explicit conversion `uint64(amount)` silently truncates large amounts, so the check and the debit use the truncated value while `transfer` pays the full `amount`; fails if it blames the `unchecked` subtraction wrapping, hedges between causes, or names any other cause.

**Hand cases:**
- pass: "`uint64(amount)` silently truncates amounts above 2^64 - 1, so withdraw checks and debits only the low 64 bits but transfers the full uint256 amount."
- pass: "The downcast to uint64 is not overflow-checked, so withdrawing 2**64 + 1 wei debits 1 wei of credit and pays out 2**64 + 1 wei."
- pass: "Credit is compared and reduced using a 64-bit copy of the amount while the payout uses the full-width number, so debit and payment can differ by multiples of 2^64."
- fail, hedge: "The unchecked subtraction can underflow, or the uint64 cast can truncate the amount; either lets a saver take more than they deposited."
- fail, near miss: "deposit's `credit += amount` overflows uint64 once a saver passes about 18.4 tokens, so their deposits revert and funds get stuck."
- fail, confident decoy: "The subtraction `c - debit` sits in an unchecked block, so a withdrawal larger than the credit wraps the balance to nearly 2^64 and lets the saver withdraw far more than they deposited."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/opus-encoding-downcast-outside-unchecked`, solc 0.8.28, optimizer 200, legacy pipeline, Cancun, OpenZeppelin 5.4.0. The test imports `src/Savings.sol`, the snippet byte for byte.
- `[PASS] testFuzz_decoy_uncheckedSubtractionNeverWraps(uint256) (runs: 512)`: for any input, credit after a withdraw is `before - uint64(amount)` or unchanged on revert, and never grows.
- `[PASS] testFuzz_decoy_inRangeWithdrawPaysWhatItDebits(uint64) (runs: 512)`: for amounts that fit in 64 bits, the tokens paid equal the credit debited, and over-credit withdraws revert with "insufficient".
- `[PASS] test_loss_castTruncatesDebitButNotPayout()`: Bob deposits 1 wei, withdraws 2^64 + 1 wei, his credit goes to 0, and he receives 2^64 + 1 wei (more than 18 tokens) from other savers' deposits.

**Your confidence a frontier model fails cold:** medium. Frontier models know silent downcasts well when the cast is the only thing in view; the `unchecked` block is what pulls the eye.

### rewards-zero-balance-skips-index
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28 and OpenZeppelin 5.4.0 on mainnet. ETH paid into `notify` belongs to whoever held shares at that moment. After 10 ETH was paid in, the contract ran out of ETH before every long-time holder had claimed.

```solidity
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ShareToken is ERC20("Share", "SHR") {
    uint256 public index;
    mapping(address => uint256) public paidIndex;
    mapping(address => uint256) public owed;
    constructor() { _mint(msg.sender, 1000e18); }
    function notify() external payable { index += msg.value * 1e18 / totalSupply(); }
    function _settle(address a) internal {
        uint256 bal = balanceOf(a);
        if (bal == 0) return;
        owed[a] += bal * (index - paidIndex[a]) / 1e18;
        paidIndex[a] = index;
    }
    function _update(address from, address to, uint256 v) internal override {
        _settle(from); _settle(to);
        super._update(from, to, v);
    }
    function claim() external {
        _settle(msg.sender);
        payable(msg.sender).transfer(owed[msg.sender]);
        owed[msg.sender] = 0;
    }
}
```

What is the root cause of the loss? Answer in one sentence.

**Answer:** `_settle` returns early for a zero balance without setting `paidIndex[a] = index`, so an address that first receives shares after a payout keeps `paidIndex` at 0, and its next settle credits its new balance with the whole history of the index, paying it ETH that belongs to earlier holders.

**Decoy:** `claim` sends ETH before `owed[msg.sender] = 0`. It cannot pay twice: `transfer` forwards only the 2,300-gas stipend, which cannot pay for a second `claim` (that needs warm reads, another value call and a storage write), so any re-entry attempt reverts the whole claim.

**Why a model gets it wrong:** Payment before the zeroing is the most famous shape in Solidity, and "ran out of ETH" reads like a drain. The early return looks like a gas saving. Seeing the real cause means tracing a fresh holder through `_update`: settle runs while its balance is still zero, so it is never stamped.

**Backing:** Code4rena, Ethereum Credit Guild contest, December 2023, H-01, **High**: "The userGaugeProfitIndex is not set correctly, allowing an attacker to receive rewards without waiting", [finding #1194](https://github.com/code-423n4/2023-12-ethereumcreditguild-findings/issues/1194) (labels: 3 (High Risk), selected for report). `ProfitManager.claimGaugeRewards` returned 0 when the user's gauge weight was 0 without setting `userGaugeProfitIndex`, so a user who voted after profit was notified collected rewards accrued before they joined, and other users' claims then failed. Contest finding, no live loss claimed.

**Decoy source:** No judged-invalid finding about re-entry through `transfer` was located within the fetch budget. Its harmlessness rests on the stipend, which ConsenSys Diligence ([Stop Using Solidity's transfer() Now](https://diligence.consensys.io/blog/2019/09/stop-using-soliditys-transfer-now), 2019) describes as sized for a log entry but not a reentrant storage-modifying call; OpenZeppelin's [Reentrancy After Istanbul](https://www.openzeppelin.com/news/reentrancy-after-istanbul) warns that this guarantee depends on gas costs. Both URLs come from search results; the pages were not opened. The proof is the evidence for the pinned EVM.

**Spec source:** Solidity documentation, [Members of Address Types](https://docs.soliditylang.org/en/v0.8.28/units-and-global-variables.html#members-of-address-types): `transfer` forwards a 2,300-gas stipend and reverts on failure. The finding's code lines are linked in #1194.

**Grading:** judge: criterion `zero_balance_skips_index`

**Judge criterion:** Passes if the reply says `_settle` returns early for a zero balance without updating `paidIndex`, so a new holder's `paidIndex` stays 0 (or stale) and it is credited with rewards from before it held shares; fails if it blames re-entry into `claim`, blames `transfer`'s stipend or failure, hedges between causes, or names any other cause.

**Hand cases:**
- pass: "_settle returns before setting paidIndex when the balance is zero, so a buyer who arrives after the 10 ETH payout keeps paidIndex 0 and claims as if it had held shares since the start."
- pass: "A first-time holder is never checkpointed because of the bal == 0 early return, so its first claim charges index - 0 against its new balance and takes earlier holders' ETH."
- pass: "New holders are not stamped with the current index on entry, so they collect payouts that happened before they owned any shares."
- fail, hedge: "Either claim's transfer before zeroing owed lets a holder re-enter, or new holders are not checkpointed; both can empty the contract."
- fail, near miss: "notify divides by totalSupply with rounding down, so dust accumulates and the last holders cannot be paid in full."
- fail, confident decoy: "claim pays out before setting owed to zero, violating checks-effects-interactions, so a holder contract re-enters claim from its receive function and is paid its owed amount repeatedly until the ETH runs out."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/opus-rewards-zero-balance-skips-index`, solc 0.8.28, optimizer 200, legacy pipeline, Cancun, OpenZeppelin 5.4.0. The test imports `src/ShareToken.sol`, the snippet byte for byte.
- `[PASS] test_decoy_reentryThroughTransferReverts()`: a holder whose `receive` calls `claim` again makes the whole claim revert (the trace shows the inner `claim` getting 1,263 gas and running out); the 10 ETH pot is intact.
- `[PASS] test_decoy_swallowedReentryAlsoReverts()`: catching the inner failure does not help; the stipend is exhausted and the claim reverts.
- `[PASS] test_decoy_plainContractHolderPaidOnce()`: a contract holder with an empty `receive`, claiming twice, receives its 5 ETH exactly once.
- `[PASS] test_loss_freshHolderCollectsHistory()`: after a 10 ETH payout to 1,000 shares, Bob receives 100 shares, `paidIndex(bob)` is 0, Bob's claim pays him 1 ETH he never earned, and the long-time holder's 10 ETH claim reverts against the 9 ETH left.

**Your confidence a frontier model fails cold:** medium. Reward-index bugs are well known, but the early return reads as harmless and the payment-before-zeroing line is the louder story.

### tokens-erc1155-batch-skips-pledge
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28 and OpenZeppelin 5.4.0. A lender accepts Heroes and Gear as loan collateral that stays in the borrower's wallet; the lender sets `pledged` (setters and minting omitted), and pledged items must not move until repayment. A borrower moved pledged items to a buyer and defaulted.

```solidity
pragma solidity 0.8.28;
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Heroes is ERC721("Heroes", "HERO") {
    mapping(uint256 => bool) public pledged;

    function transferFrom(address from, address to, uint256 id) public override {
        require(!pledged[id], "pledged");
        super.transferFrom(from, to, id);
    }
}

contract Gear is ERC1155("") {
    mapping(address => mapping(uint256 => uint256)) public pledged;

    function safeTransferFrom(address from, address to, uint256 id, uint256 n, bytes memory data)
        public override
    {
        require(balanceOf(from, id) >= pledged[from][id] + n, "pledged");
        super.safeTransferFrom(from, to, id, n, data);
    }
}
```

What is the root cause of the loss? Answer in one sentence.

**Answer:** Gear checks the pledge only in `safeTransferFrom`, and OpenZeppelin 5.4.0's `safeBatchTransferFrom` does not call `safeTransferFrom` (it goes to `_safeBatchTransferFrom` and `_update`), so the borrower moves pledged Gear in a batch; Heroes is sound because 5.4.0's `safeTransferFrom` calls the overridden `transferFrom`.

**Decoy:** Heroes overrides only `transferFrom`, the exact shape of AI Arena's locked-fighter High, where the four-argument `safeTransferFrom` skipped the check. In OpenZeppelin 5.4.0 both `safeTransferFrom` overloads call the public, virtual `transferFrom`, so every Hero route hits the pledge check.

**Why a model gets it wrong:** The AI Arena finding and the OpenZeppelin 4.x rule ("override `_beforeTokenTransfer`, not the public functions") are widely taught, so a model that sees a `transferFrom`-only override reports the safe-transfer hole without checking the pinned version. The ERC-1155 contract looks like the careful one because it overrides the "safe" function, the only single-item transfer ERC-1155 has.

**Backing:** Code4rena, AI Arena contest, February 2024, H-02, **High**: "Non-transferable `GameItems` can be transferred with `GameItems::safeBatchTransferFrom(...)`", [finding #575](https://github.com/code-423n4/2024-02-ai-arena-findings/issues/575) (labels: 3 (High Risk), selected for report, sponsor confirmed). GameItems overrode `safeTransferFrom` with the transferability check but not `safeBatchTransferFrom`. Contest finding, no live loss claimed.

**Decoy source:** Code4rena, AI Arena contest, February 2024, H-01, **High** under the code it reviewed: "A locked fighter can be transferred", [finding #1709](https://github.com/code-423n4/2024-02-ai-arena-findings/issues/1709). FighterFarm overrode `transferFrom` and the three-argument `safeTransferFrom` but not the four-argument one, which in OpenZeppelin 4.x calls `_safeTransfer` directly. This decoy is a valid finding made harmless by the pinned version, not a judged-invalid one; the contrast proof below shows the same file moving a pledged Hero on 4.9.6.

**Spec source:** OpenZeppelin Contracts 5.4.0 [ERC721.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/token/ERC721/ERC721.sol): `safeTransferFrom(from, to, tokenId, data)` is `transferFrom(from, to, tokenId); ERC721Utils.checkOnERC721Received(...)` (local copy lines 133 to 136). [ERC1155.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/token/ERC1155/ERC1155.sol): `safeBatchTransferFrom` checks approval and calls `_safeBatchTransferFrom`, which calls `_updateWithAcceptanceCheck`; it never calls `safeTransferFrom` (local copy lines 99 to 120, 235 to 249). In 4.9.6, `ERC721.safeTransferFrom(..., data)` calls `_safeTransfer` (local copy lines 167 to 170).

**Grading:** judge: criterion `batch_path_skips_gear_pledge`

**Judge criterion:** Passes if the reply says Gear's pledge check is skipped by `safeBatchTransferFrom`, because the batch path does not go through the overridden `safeTransferFrom`, so pledged Gear can be moved; fails if it says a pledged Hero can be moved (through `safeTransferFrom` with or without data, or any other Heroes path), hedges between causes, or names any other cause.

**Hand cases:**
- pass: "Gear only overrides safeTransferFrom, so safeBatchTransferFrom never runs the pledge check and the borrower can batch-transfer pledged Gear to the buyer."
- pass: "The ERC-1155 batch path is unguarded: in OpenZeppelin 5.4.0 safeBatchTransferFrom does not call safeTransferFrom, so pledged Gear moves in a batch of one."
- pass: "Gear's pledge rule sits on one public entry point instead of _update, and the batch transfer reaches _update without it."
- fail, hedge: "Heroes can be moved with safeTransferFrom(from, to, id, data), which skips the transferFrom override, and Gear can be moved with safeBatchTransferFrom."
- fail, near miss: "An approved operator can move pledged items, because the pledge check only runs when the owner calls the transfer."
- fail, confident decoy: "Heroes overrides transferFrom but not safeTransferFrom(address,address,uint256,bytes), which goes straight to _safeTransfer, so the borrower moves a pledged Hero with a safe transfer and the check never runs."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/opus-tokens-erc1155-batch-skips-pledge`, solc 0.8.28, optimizer 200, legacy pipeline, Cancun, OpenZeppelin 5.4.0. The test imports `src/Collateral.sol`, the snippet byte for byte; test-only children add minting and the pledge setters.
- `[PASS] test_decoy_everyHeroRouteHitsThePledgeCheck()`: `transferFrom`, both `safeTransferFrom` overloads (empty and non-empty data), and an approved operator's safe transfer all revert with "pledged"; the Hero stays with the borrower.
- `[PASS] test_loss_batchTransferMovesPledgedGear()`: single `safeTransferFrom` of pledged Gear reverts with "pledged"; `safeBatchTransferFrom` of the same ten items succeeds and the buyer holds all ten.
- Contrast, `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/opus-tokens-erc1155-batch-skips-pledge/oz496-contrast` (same file, `cmp`-identical, compiled against OpenZeppelin 4.9.6): `[PASS] test_contrast_oz496SafeTransferSkipsOverride()`: `transferFrom` reverts, but `safeTransferFrom(borrower, buyer, 1, "")` moves the pledged Hero. The decoy is harmless only on the pinned version.

**Your confidence a frontier model fails cold:** high. This has the shape of the earlier wins: a famous finding reproduced on a version where it no longer holds, next to a quieter version of its sibling.

### callbacks-safemint-reenters-claim
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28; `usdc` is an unmodified OpenZeppelin 5.4.0 ERC20 with 6 decimals, and each win pays 100 USDC plus a trophy. The draw that records wins is omitted. A winner with one win collected 500 USDC.

```solidity
pragma solidity 0.8.28;
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Prizes is ERC721("Trophy", "TRO") {
    IERC20 public immutable usdc;
    mapping(address => uint256) public wins;
    uint256 public nextId;
    constructor(IERC20 t) { usdc = t; }

    function claim() external {
        uint256 n = wins[msg.sender];
        for (uint256 i; i < n; i++) {
            require(usdc.transfer(msg.sender, 100e6));
            _safeMint(msg.sender, nextId++);
        }
        wins[msg.sender] = 0;
    }
}
```

What is the root cause of the loss? Answer in one sentence.

**Answer:** `_safeMint` calls the winner's `onERC721Received` before `wins[msg.sender]` is zeroed, so a winner contract re-enters `claim` from the hook and is paid its 100 USDC again on every nested call.

**Decoy:** `usdc.transfer` also runs before the zeroing, but an unmodified OpenZeppelin ERC20 `transfer` only updates balances and emits an event; it never calls the recipient, so it hands no control to the winner.

**Why a model gets it wrong:** Both external calls sit before `wins[msg.sender] = 0`, and the token transfer is the classic one. A reader who stops at "external call before the state update" names the USDC transfer, or names neither. The mint looks like an internal call because `_safeMint` has an underscore and the word "safe".

**Backing:** Code4rena, AI Arena contest, February 2024, H-08, **High**: "Player can mint more fighter NFTs during claim of rewards by leveraging reentrancy on the `claimRewards()` function", [finding #37](https://github.com/code-423n4/2024-02-ai-arena-findings/issues/37) (labels: 3 (High Risk), selected for report, sponsor confirmed). `MergingPool.claimRewards` minted each prize fighter through `_safeMint` before the claim counter was final, so a winner contract re-entered from `onERC721Received` and minted extra fighters. Contest finding, no live loss claimed.

**Decoy source:** Code4rena, Sherlock contest, January 2022, [finding #60](https://github.com/code-423n4/2022-01-sherlock-findings/issues/60), "Reenterancy in `_sendSherRewardsToOwner()`": the judge downgraded it (labels: 2 (Med Risk), disagree with severity) because "the SHER token is a known token that currently comes with no such hooks like ERC777". Also Code4rena, Float Capital contest, August 2021, [finding #57](https://github.com/code-423n4/2021-08-floatcapital-findings/issues/57), labelled invalid and sponsor disputed: "Re-entrancy not possible since we don't use erc20 tokens with hooks as payment tokens."

**Spec source:** OpenZeppelin Contracts 5.4.0 [ERC721.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/token/ERC721/ERC721.sol): `_safeMint(to, tokenId, data)` is `_mint(to, tokenId); ERC721Utils.checkOnERC721Received(...)` (local copy lines 287 to 290). [ERC20.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/token/ERC20/ERC20.sol): `transfer` calls `_transfer` and `_update`, which change balances and emit `Transfer` with no external call (local copy lines 99, 159, 176).

**Grading:** judge: criterion `safemint_hook_reenters_claim`

**Judge criterion:** Passes if the reply says `_safeMint` hands control to the winner through `onERC721Received` (the ERC-721 receiver hook) before `wins` is zeroed, so the winner re-enters `claim` and is paid again; fails if it names the USDC transfer as the way back in, says only that state is updated after external calls without naming the mint's hook, hedges between causes, or names any other cause.

**Hand cases:**
- pass: "_safeMint calls onERC721Received on the winner before wins is set to zero, so a winner contract re-enters claim from that hook and collects the 100 USDC prize again each time."
- pass: "The trophy mint is a safe mint, which calls back into the recipient contract while wins still holds 1, letting it call claim recursively."
- pass: "Control returns to the winner through the ERC-721 receiver callback during minting, and because the win count is cleared only after the loop, every nested claim pays again."
- fail, hedge: "claim clears wins only after its external calls, so a winner contract can re-enter through the USDC transfer or the mint and collect again."
- fail, near miss: "_safeMint reverts for a winner contract that does not implement onERC721Received, so that winner's prize is locked and never paid."
- fail, confident decoy: "claim transfers USDC to the winner before zeroing wins, violating checks-effects-interactions, so a malicious winner contract re-enters claim on each transfer and is paid repeatedly."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/opus-callbacks-safemint-reenters-claim`, solc 0.8.28, optimizer 200, legacy pipeline, Cancun, OpenZeppelin 5.4.0. The test imports `src/Prizes.sol`, the snippet byte for byte; a test-only child sets `wins`.
- `[PASS] test_decoy_usdcTransferGivesNoControl()`: a winner contract whose fallback would re-enter, and whose hook does not, gets one prize; its fallback ran 0 times, re-entry depth is 0, and a second claim pays nothing.
- `[PASS] test_loss_safeMintHookReentersClaim()`: the same winner with a re-entering `onERC721Received` (capped at depth 4) receives 500 USDC and five trophies for one win; its fallback ran 0 times, so control came only from the hook.

**Your confidence a frontier model fails cold:** low to medium. `_safeMint` reentrancy is well documented, so frontier models probably pass; the value is in catching replies that blame the token transfer or stay generic.

### access-lock-for-resets-timer
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28; every listed token is an unmodified OpenZeppelin 5.4.0 ERC20. On day 0 Bob locked 1,000 of token 0 for himself with `lockFor`. On day 90 `unlock` still reverts for him, and his tokens stay in the contract.

```solidity
pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Locker {
    address public immutable admin = msg.sender;
    IERC20[] public tokens;
    mapping(address => mapping(uint256 => uint256)) public locked;
    mapping(address => uint256) public unlockAt;
    function list(IERC20 t) external {
        require(msg.sender == admin && tokens.length < 5);
        tokens.push(t);
    }
    function lockFor(address who, uint256 i, uint256 amount) external {
        require(tokens[i].transferFrom(msg.sender, address(this), amount));
        locked[who][i] += amount;
        unlockAt[who] = block.timestamp + 30 days;
    }
    function unlock() external {
        require(block.timestamp >= unlockAt[msg.sender], "locked");
        for (uint256 i; i < tokens.length; i++) {
            uint256 a = locked[msg.sender][i];
            locked[msg.sender][i] = 0;
            require(tokens[i].transfer(msg.sender, a));
        }
    }
}
```

What is the root cause of the loss? Answer in one sentence.

**Answer:** `lockFor` lets anyone write `unlockAt` for any address, so a stranger calling `lockFor(bob, 0, 0)` (a zero amount needs no allowance) shortly before each expiry pushes Bob's unlock back another 30 days, indefinitely.

**Decoy:** `unlock` loops over every listed token and calls `transfer` even for tokens Bob never locked, which reads as an unbounded loop and as the "reverts on zero-value transfer" weird-token problem. Both are harmless here: `list` caps the array at five admin-chosen tokens, and OpenZeppelin ERC20 accepts zero-value transfers.

**Why a model gets it wrong:** The loss reads as "unlock reverts", and the loop with external calls inside it is the familiar cause of a reverting withdrawal. The real cause is in a different function and looks like a convenience feature (locking for a friend), not an access-control path.

**Backing:** Code4rena, Munchables contest, May 2024, H-01, **High**: "Malicious User can call `lockOnBehalf` repeatedly extend a users `unlockTime`, removing their ability to withdraw previously locked tokens", [finding #165](https://github.com/code-423n4/2024-05-munchables-findings/issues/165) (labels: 3 (High Risk), selected for report). `LockManager.lockOnBehalf` set the receiver's `unlockTime = block.timestamp + lockDuration` and had no minimum quantity. Contest finding, no live loss claimed.

**Decoy source:** Code4rena, Y2K Finance contest, September 2022, [finding #405](https://github.com/code-423n4/2022-09-y2k-finance-findings/issues/405), "`Vault.withdraw()` might revert when `feeValue = 0` and `asset` is a `revert on zero value transfers` token", labelled invalid, sponsor disputed, unsatisfactory; and Code4rena, Tribe contest, September 2022, [finding #183](https://github.com/code-423n4/2022-09-tribe-findings/issues/183), same claim for `TribeRedeemer.redeem()`, invalid, sponsor disputed. For the loop: Code4rena, Frax contest, August 2022, [finding #340](https://github.com/code-423n4/2022-08-frax-findings/issues/340), "Unbounded loop while iterating `deployedPairsArray`", invalid, sponsor disputed.

**Spec source:** OpenZeppelin Contracts 5.4.0 [ERC20.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/token/ERC20/ERC20.sol): `transferFrom` (local copy line 142) spends allowance through `_spendAllowance`, which reverts only if `currentAllowance < value`, so a value of 0 always passes (lines 294 to 304); `_update` handles a value of 0 like any other.

**Grading:** judge: criterion `lock_for_resets_unlock`

**Judge criterion:** Passes if the reply says anyone can call `lockFor` with Bob's address, and that call resets `unlockAt[who]`, so a third party (with a zero or tiny amount) keeps pushing Bob's unlock back; fails if it blames the loop's length or gas, a token reverting on zero-value or failed transfers, hedges between causes, or names any other cause.

**Hand cases:**
- pass: "lockFor resets unlockAt for whatever address it is given, so anyone can keep pushing Bob's unlock 30 days ahead with a zero or dust lock."
- pass: "Third parties can lock on Bob's behalf, and every such lock restarts his 30-day timer, so a stranger can keep his tokens locked indefinitely."
- pass: "The lock-for-someone path has no consent check and overwrites the beneficiary's unlock time, letting any caller extend another user's lock."
- fail, hedge: "Either the loop over tokens runs out of gas, or a stranger keeps resetting Bob's unlock time through lockFor."
- fail, near miss: "lockFor lets anyone add tokens to Bob's position, so his locked balance changes and unlock pays out the wrong amount."
- fail, confident decoy: "unlock calls transfer for every listed token even when Bob's locked amount is zero; a token that reverts on zero-value transfers makes the whole unlock revert, so Bob's 1,000 tokens are stuck."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/opus-access-lock-for-resets-timer`, solc 0.8.28, optimizer 200, legacy pipeline, Cancun, OpenZeppelin 5.4.0. The test imports `src/Locker.sol`, the snippet byte for byte.
- `[PASS] test_decoy_cappedLoopWithZeroTransfersUnlocks()`: a sixth `list` reverts; with five listed tokens, four of them never locked, Bob's unlock on day 30 succeeds, returns his 1,000 tokens and uses under 200,000 gas.
- `[PASS] test_loss_strangerKeepsResettingBobsUnlock()`: a stranger with no tokens calls `lockFor(bob, 0, 0)` on days 29, 58 and 87; on day 90 Bob's unlock reverts with "locked", `unlockAt` is day 117, and the stranger spent nothing.

**Your confidence a frontier model fails cold:** low. Lock-on-behalf griefing is a widely taught pattern; this one mainly checks whether open models are pulled to the loop.

## Summary

| Slug | Decoy (harmless) | Real cause | Real-cause source |
| --- | --- | --- | --- |
| `callbacks-hook-credits-operator` | NFT `transferFrom` before `delete` (ERC-721 `transferFrom` has no receiver call) | hook stores the operator argument as the owner | Code4rena papr H-03 |
| `encoding-downcast-outside-unchecked` | `unchecked` subtraction guarded by `require` | `uint64(amount)` truncates the debit, payout uses the full amount | Code4rena Escher M-08 |
| `rewards-zero-balance-skips-index` | ETH `transfer` before zeroing `owed` (2,300-gas stipend) | zero-balance early return never stamps a new holder's index | Code4rena Ethereum Credit Guild H-01 |
| `tokens-erc1155-batch-skips-pledge` | ERC-721 overrides only `transferFrom` (OZ 5.4.0 routes both safe transfers through it) | ERC-1155 `safeBatchTransferFrom` skips the `safeTransferFrom` check | Code4rena AI Arena H-02 (decoy shape: H-01) |
| `callbacks-safemint-reenters-claim` | USDC `transfer` before zeroing `wins` (hookless OZ ERC20) | `_safeMint` hook re-enters `claim` | Code4rena AI Arena H-08 |
| `access-lock-for-resets-timer` | loop over listed tokens with zero-value transfers (capped at 5, OZ allows zero) | anyone's `lockFor(bob, i, 0)` resets Bob's unlock time | Code4rena Munchables H-01 |

Every proof is two-sided: the decoy tests show the textbook smell cannot lose funds on the pinned versions, and the loss tests show the real cause does. Run all seven projects with `forge test --offline -vv --root <project>`; 17 of 17 tests pass. `python3 /tmp/subagents/security-quizzes/check-decoy-opus.py` checks form: opener and closer, under 160 words, 12 to 25 code lines (the snippets are 19 to 25 lines including blanks), no banned or hinting words, slug not reused, snippet byte-identical to the proof's `src/` file, and the six hand cases with a confident decoy fail.

## Ground not covered

Compiler-pipeline differences on current versions: the documented legacy versus via-IR differences that still exist (initializer order, evaluation order, struct-delete padding, modifier return-variable reset, memory-to-storage `bytes` copy) are either already used in `pilot-opus.md` or need assembly or a contrived modifier to cause a loss. Old compiler bugs used as decoys were left out, following the brief.

## Sourcing

5 web searches, 0 page fetches. About 40 GitHub API lookups (issue views for labels and bodies, and issue searches, about a dozen of which returned nothing). I counted only the web searches against the 30-fetch budget; if the GitHub lookups count too, the budget was exceeded. Every finding cited as valid, invalid or disputed had its labels read through the GitHub API. Unopened URLs are marked as such in their entries.

## Rejected on the way

- Delete of a struct with a nested mapping as the real cause: the Code4rena findings for it are Low; the Munchables claims (#113, #114, #315) were unsatisfactory because proposal-id stamps made the stale mapping harmless. Kept as a decoy idea, not used because no real cause in the same snippet had a clear loss.
- Munchables M-01 (approve path misses the disapproval check) as the real cause: valid Medium, but the loss in a reduced snippet is too indirect.
- Munchables H-02 (`setLockDuration` checks `block.timestamp + d` but writes `lastLockTime + d`): quiet and valid, but the loss (early unlock after half the lock) is weak in a standalone snippet.
- `abi.encodePacked` with one dynamic argument as a decoy: no real cause found that fits the same short snippet with a loss story both readings explain.
- Unauthenticated `onERC721Received` (missing caller check): no valid High or Medium located; the papr operator-argument bug replaced it.
- ERC-1155 `_mint` always calling the receiver hook: no valid finding located within budget; the `_safeMint` variant from AI Arena H-08 replaced it.
- Unbounded rounds loop (AI Arena M-04) as a gas real cause: "a long-idle winner cannot claim" points straight at the loop, so no decoy stays plausible.
