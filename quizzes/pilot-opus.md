# Execution-checked security candidates (opus drafter: compiler/EVM, storage and upgrades, signatures)

Every candidate below has a Foundry proof under `/tmp/subagents/security-quizzes/pilot/<slug>/`. Each foundry.toml pins `solc`, `via_ir`, `optimizer` and `evm_version`. No test forks or touches the network. Predictions were written to `pilot/PREDICTIONS-opus.md` before the first `forge test` run of each candidate. No model trials have run, so every "confidence a frontier model fails" line is a guess. A rerun of every proof is in `pilot/ALL-opus.log` (all green).

12 candidates, by primary shape:
- Shape 1, the shape predicts a problem but the behaviour is fine (4): signatures-packed-array-typed-data, forwarder-multicall-suffix-oz5, evm-transfer-refund-to-safe, compiler-eval-order-self-transfer (numeric answer)
- Shape 2, the shape predicts safety but there is a gap (6): compiler-legacy-init-order, compiler-transient-clear-collision, compiler-memory-bytes-delete, upgrades-oz4-to-oz5-initializer, signatures-eip712-proxy-domain, evm-try-catch-empty-return
- Shape 3, exact outcome (2): compiler-tuple-assignment-self-transfer (60), upgrades-stateless-parent-gap (0)

Two candidates (transient-clear-collision, memory-bytes-delete) turn on compiler bugs disclosed in February and September 2026. They reward knowing the disclosure more than reading the code. They are flagged in each entry so the owner can decide.

---

### compiler-legacy-init-order
**Instruction:**
You are reviewing this fee vault before launch. It is compiled with Solidity 0.8.30, optimizer on, legacy pipeline (no via-IR). `Ownable` is OpenZeppelin Contracts 5.4.

```solidity
contract FeeVault is Ownable {
    address public feeRecipient = owner();

    constructor() Ownable(msg.sender) {}

    function collectFees() external {
        payable(feeRecipient).transfer(address(this).balance);
    }
}
```

Alice's EOA deploys it. Right after deployment, what does `feeRecipient()` return? Answer Alice's address or the zero address, then explain in one sentence.

**Answer:** The zero address. The legacy pipeline runs every state-variable initializer in the hierarchy before any constructor, so `owner()` still reads 0 when `feeRecipient` is set, and `Ownable`'s constructor only sets `_owner` afterwards. (Under via-IR the same source gives Alice's address.)

**Why a model gets it wrong:** Readers assume Solidity builds each base completely (state variables, then the constructor) before the derived contract's initializers run. That is the via-IR order. The legacy order differs, and it is still Foundry's and Hardhat's default.

**Backing:** No money-loss incident found. The Solidity docs list this as a semantic difference between the pipelines, with the same `y = f()` pattern: https://docs.soliditylang.org/en/latest/ir-breaking-changes.html#state-variable-initialization-order

**Spec source:** https://docs.soliditylang.org/en/latest/ir-breaking-changes.html (section "State variable initialization order")

**Grading:** pattern: starts with "zero" or "the zero address" (also accept "address(0)" / "0x0")

**Predicted:** Zero address on legacy and Alice on via-IR (from the docs example). Prediction right. A careful reader would miss that the legacy pipeline runs every initializer in the whole hierarchy before any constructor.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-legacy-init-order && forge test` → `[PASS] testLegacyFeeRecipientIsZero() (gas: 387894)`. Contrast: `FOUNDRY_PROFILE=viair forge test` → `[PASS] testViaIRFeeRecipientIsDeployer() (gas: 398491)`

**Your confidence a frontier model fails cold:** medium

---

### compiler-eval-order-self-transfer
**Instruction:**
You are reviewing this token, compiled with Solidity 0.8.30, optimizer on, legacy pipeline (no via-IR).

```solidity
mapping(address => uint256) public balanceOf;

function transfer(address to, uint256 amount) external {
    balanceOf[to] = balanceOf[to] + _debit(msg.sender, amount);
}

function _debit(address from, uint256 amount) internal returns (uint256) {
    balanceOf[from] -= amount;
    return amount;
}
```

Alice holds 100 tokens and calls `transfer(alice, 40)`, sending to herself. What is `balanceOf(alice)` afterwards? Answer with the number only.

**Answer:** 100. The legacy code generator evaluates the right operand of `+` first, so `_debit` runs (100 → 60) before `balanceOf[to]` is read (60), and 60 + 40 = 100. The same source compiled via-IR evaluates left to right, reads 100 before the debit, and ends at 140.

**Why a model gets it wrong:** The line has the shape of the classic self-transfer inflation bug: the recipient's balance is read, the sender is debited, and the stale read is written back. Reading in source order gives 140. The docs call the legacy evaluation order unspecified, and in practice it runs the right operand first.

**Backing:** Super Sushi Samurai, 21 March 2024, about $4.8M: self-transfers doubled the attacker's balance because both balances were read before either write (https://blog.solidityscan.com/super-sushi-samurai-hack-analysis-ae96b76a6252/; team post-mortem not checked).

**Spec source:** https://docs.soliditylang.org/en/latest/ir-breaking-changes.html (evaluation order: legacy `++a + a` with a = 1 gives 3, via-IR gives 4)

**Grading:** pattern: starts with "100"

**Predicted:** 100 on legacy and 140 on via-IR (from the docs' `++a + a` example). Prediction right. While exploring I also ran `balanceOf[to] = _debit(...) + balanceOf[to]`, which I had not predicted beforehand. It gives 140 on legacy and 100 on via-IR, and would make a mirror-image question. `+=` gives 100 on both.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-eval-order-self-transfer && forge test` → `[PASS] testSelfTransferLegacy() (gas: 151020)`. Contrast: `FOUNDRY_PROFILE=viair forge test` → `[PASS] testSelfTransferViaIR() (gas: 113991)`. Also passes with `FOUNDRY_OPTIMIZER=false`.

**Your confidence a frontier model fails cold:** high

---

### compiler-tuple-assignment-self-transfer
**Instruction:**
You are reviewing this token, compiled with Solidity 0.8.30, optimizer on.

```solidity
mapping(address => uint256) public balanceOf;

function transfer(address to, uint256 amount) external {
    uint256 fromBal = balanceOf[msg.sender];
    uint256 toBal = balanceOf[to];
    require(fromBal >= amount, "balance");
    (balanceOf[msg.sender], balanceOf[to]) = (fromBal - amount, toBal + amount);
}
```

Alice holds 100 tokens and calls `transfer(alice, 40)`, sending to herself. What is `balanceOf(alice)` afterwards? Answer with the number only.

**Answer:** 60. Both sides of the tuple are computed from the cached balances (60, 140). Solidity then writes the components from right to left, so `balanceOf[to] = 140` is written first and `balanceOf[msg.sender] = 60` overwrites it. Alice loses 40 tokens.

**Why a model gets it wrong:** It is the textbook self-transfer bug shape (both balances cached, then written back), and the textbook outcome is inflation to 140. Reading the tuple as "assign left, then right" also gives 140. The result is the opposite direction, and it is the same on both pipelines, so pipeline knowledge does not help.

**Backing:** Super Sushi Samurai, 21 March 2024, about $4.8M: self-transfers inflated balances through cached reads (https://blog.solidityscan.com/super-sushi-samurai-hack-analysis-ae96b76a6252/). This tuple form deflates instead, so here the loss falls on the sender (a user who sends to themselves, or any flow that routes funds through `to == from`).

**Spec source:** Not specified in the Solidity docs (the destructuring-assignment section gives no component order: https://docs.soliditylang.org/en/latest/control-structures.html#destructuring-assignments-and-returning-multiple-values). The answer rests on execution, which is stable across 0.8.20, 0.8.24, 0.8.30 and 0.8.33, legacy and via-IR, with the optimizer on or off.

**Grading:** pattern: starts with "60"

**Predicted:** Written before the run (P17): 60 on legacy (right-to-left) and 140 on via-IR. **Wrong for via-IR**: via-IR also writes right to left and gives 60. This is the one candidate where my written prediction failed.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-tuple-assignment-self-transfer && forge test` → `[PASS] testSelfTransferEndsAt60() (gas: 156605)`, `[PASS] testNormalTransfer() (gas: 179399)`. Also `FOUNDRY_PROFILE=viair forge test` → `[PASS] testSelfTransferEndsAt60() (gas: 128925)`. `forge test --use 0.8.20|0.8.24|0.8.33` on both profiles and `FOUNDRY_OPTIMIZER=false forge test` all pass (see run.log).

**Your confidence a frontier model fails cold:** high

**Note for the consolidator:** this candidate and `compiler-eval-order-self-transfer` share the self-transfer theme. If only one is kept, keep this one: its answer does not depend on the pipeline, and it reverses the famous direction.

---

### compiler-transient-clear-collision
**Instruction:**
You are reviewing this vault, compiled with Solidity 0.8.33, via-IR, optimizer on, EVM version cancun. `Ownable2Step` is OpenZeppelin Contracts 5.4.

```solidity
contract Vault is Ownable2Step {
    address transient activeCaller;

    constructor() Ownable(msg.sender) {}

    function run() external {
        activeCaller = msg.sender;
        // ... work that reads activeCaller ...
        delete activeCaller;
    }
}
```

The deployer calls `transferOwnership(bob)`, Bob calls `acceptOwnership()`, and later Bob calls `renounceOwnership()`. Can Bob then call `acceptOwnership()` again and become owner? Answer yes or no, then explain in one sentence.

**Answer:** Yes. Under the TransientStorageClearingHelperCollision bug (0.8.28 to 0.8.33, via-IR), `delete activeCaller` and Ownable2Step's `delete _pendingOwner` share one `set_to_zero` helper. In this contract the shared helper clears transient storage, so `_pendingOwner` is never cleared. Bob stays pending after accepting and after renouncing, and can accept again.

**Why a model gets it wrong:** Ownable2Step plus `renounceOwnership` is the textbook "ownership is gone for good" sequence, and `delete` on a transient variable looks unrelated to ownership. Catching it means knowing a high-severity bug disclosed in February 2026 and seeing that both conditions (a transient `delete` and a persistent `delete` of a matching value type in the same bytecode) are met.

**Backing:** Solidity disclosure, 18 February 2026, severity high: https://blog.soliditylang.org/2026/02/18/transient-storage-clearing-helper-collision-bug/ (conditions taken from the compiler's own bugs.json: https://github.com/ethereum/solidity/blob/develop/docs/bugs.json). No exploit known.

**Spec source:** https://github.com/ethereum/solidity/blob/develop/docs/bugs.json (entry "TransientStorageClearingHelperCollision": introduced 0.8.28, fixed 0.8.34, viaIR, evm >= cancun)

**Grading:** pattern: starts with "yes"

**Predicted:** I expected one of the two deletes to clear the wrong location but could not tell which. I guessed the persistent `delete _pendingOwner` would become a TSTORE. That guess was right, but it was a coin flip. A second prediction, written before its run (P15), also held: the same contract with the common `bool transient locked` guard and `delete locked` is unaffected, because the helper names differ by type (bool vs address). So the transient variable's type matters to the question, and a reader who knows the bug still has to match types (scratch run in `pilot/_scratch-transient-bool`, output `pendingAfterRenounce=zero`).

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-transient-clear-collision && forge test` → `[PASS] testBobReclaimsAfterRenounce() (gas: 226770)`. Controls: `FOUNDRY_PROFILE=fixed forge test` (solc 0.8.34) → `[PASS] testRenounceIsFinal() (gas: 183060)`. `FOUNDRY_PROFILE=legacy forge test` (0.8.33, no via-IR) → `[PASS] testRenounceIsFinal() (gas: 189773)`

**Your confidence a frontier model fails cold:** high (needs a 2026 disclosure plus matching the conditions; open models very likely miss it)

---

### upgrades-oz4-to-oz5-initializer
**Instruction:**
You are reviewing a vault upgrade. V1 uses OpenZeppelin Contracts Upgradeable 4.9.6 (`Initializable`, `OwnableUpgradeable`, `UUPSUpgradeable`) and was initialized at launch with the team's Safe as owner. V2 is the same vault rebuilt on OpenZeppelin Contracts Upgradeable 5.4, keeping

```solidity
function initialize(address owner_) external initializer {
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();
}
```

The Safe upgrades the proxy to V2 and passes no call data. Afterwards, can a stranger call `initialize(stranger)` and become owner? Answer yes or no, then explain in one sentence.

**Answer:** Yes. OZ 5.x keeps the initializer version and the owner in ERC-7201 namespaced slots, which are empty in this proxy, while 4.9.6 kept them in slot 0 and slot 51. Right after the upgrade, `initializer` sees version 0 and `owner()` returns the zero address, so the first caller of `initialize` takes ownership.

**Why a model gets it wrong:** The `initializer` modifier and the fact that V1 was initialized long ago are the textbook reasons a second `initialize` reverts. The OZ major-version storage break sits in a README line, not in the code under review, and the code looks unchanged.

**Backing:** No incident found. OpenZeppelin's own warning: "For upgradeable contracts, the storage layout of different major versions should be assumed incompatible, for example, it is unsafe to upgrade from 4.9.3 to 5.0.0" (README of @openzeppelin/contracts-upgradeable 5.4.0; https://docs.openzeppelin.com/contracts/backwards-compatibility).

**Spec source:** OZ 5.4 `proxy/utils/Initializable.sol` (`INITIALIZABLE_STORAGE = 0xf0c57e16…c6a00`) and `access/OwnableUpgradeable.sol` (`OwnableStorageLocation = 0x9016d09d…99300`): https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/tree/v5.4.0/contracts

**Grading:** pattern: starts with "yes"

**Predicted:** Written before the run (P19): `owner()` reads zero and a stranger can initialize. Prediction right. A careful reader would miss that the guard's own flag moved to a new slot. Likely known to frontier models that recall OZ's compatibility warning.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/upgrades-oz4-to-oz5-initializer && forge test` → `[PASS] testStrangerInitializesV2() (gas: 1467443)` and `[PASS] testOwnerReadsZeroAfterUpgrade() (gas: 1419747)` (the helper also asserts that V1 itself rejects a second initialize)

**Your confidence a frontier model fails cold:** low to medium

---

### upgrades-stateless-parent-gap
**Instruction:**
You are reviewing a V2 upgrade of a UUPS vault built on OpenZeppelin Contracts Upgradeable 4.9.6.

```solidity
contract VaultV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => uint256) public balanceOf;
    // ...
}

contract VaultV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable, MulticallUpgradeable {
    mapping(address => uint256) public balanceOf;
    // ... same functions as V1
}
```

V2 only appends `MulticallUpgradeable` so users can batch calls. Alice's V1 balance is 100. The owner upgrades the proxy to V2 with no migration. What does `balanceOf(alice)` return afterwards? Answer with the number only.

**Answer:** 0. `MulticallUpgradeable` 4.9.6 has no variables but still declares `uint256[50] private __gap`, so appending it moves `balanceOf` from slot 201 to slot 251. The owner is unaffected.

**Why a model gets it wrong:** Multicall is the textbook stateless mixin, so "it adds no storage" feels safe, and appending a parent at the end looks like the safe place to add it. In the 4.x upgradeable package, though, every contract, stateless or not, carries a 50-slot gap.

**Backing:** No incident found. The OpenZeppelin Upgrades plugin rejects this layout change. MulticallUpgradeable 4.9.6 source: https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v4.9.6/contracts/utils/MulticallUpgradeable.sol

**Spec source:** https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps and the `__gap` line in the file above (checked in the npm package 4.9.6)

**Grading:** pattern: starts with "0"

**Predicted:** 0 with the owner preserved. Prediction right. A careful reader would miss the `__gap` in a contract with no state.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/upgrades-stateless-parent-gap && forge test` → `[PASS] testAppendedMulticallMovesBalances() (gas: 1699746)`. `forge inspect` shows balanceOf at slot 201 in V1 and 251 in V2.

**Your confidence a frontier model fails cold:** medium

---

### signatures-eip712-proxy-domain
**Instruction:**
You are reviewing a share token. Its implementation inherits OpenZeppelin Contracts 5.4 `ERC20Permit` from the non-upgradeable package, constructed with `ERC20("Liquid Restaked Ether Vault Share", "lrVS")` and `ERC20Permit("Liquid Restaked Ether Vault Share")`. Users reach it through an ERC1967Proxy whose `initialize` only mints. The front end builds each permit's EIP-712 domain from the token's ERC-5267 `eip712Domain()` read through the proxy, and holders sign that domain. Does `permit` on the proxy accept these signatures? Answer yes or no, then explain in one sentence.

**Answer:** No. The name is 33 bytes, too long for OZ's `ShortString` immutable, so the constructor writes it to the `_nameFallback` storage variable in the implementation's own storage. Through the proxy, `eip712Domain()` therefore reports an empty name. `_domainSeparatorV4` still uses the immutable `_hashedName` of the full name, so signatures over the reported domain fail.

**Why a model gets it wrong:** A reader who knows OZ's EIP712 well remembers that it rebuilds the separator whenever `address(this)` differs from the cached address, from name and version hashes held as immutables. So it "works behind a proxy". That is true for the separator and for names of 31 bytes or less (both checked in the proof). It is false for the reported name of a long one. A shallower reader who answers "no" because "constructor state is missing behind a proxy" gets the right answer for the wrong field.

**Backing:** No incident found. ERC-5267 exists so that wallets and libraries can read the domain on-chain instead of hard-coding it, so a wrong report breaks every client that trusts it.

**Spec source:** OpenZeppelin Contracts 5.4 `utils/cryptography/EIP712.sol` (constructor `_name = name.toShortStringWithFallback(_nameFallback)`, `_hashedName = keccak256(bytes(name))`, `_EIP712Name()` returns `_name.toStringWithFallback(_nameFallback)`) and `utils/ShortStrings.sol` (`if (bytes(value).length < 32) ... else` write to storage): https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/utils/cryptography/EIP712.sol. ERC-5267: https://eips.ethereum.org/EIPS/eip-5267

**Grading:** pattern: starts with "no"

**Predicted:** Before running I predicted three things: a permit over the proxy-address domain is accepted, `name()` is empty through the proxy, and with a name over 31 bytes `eip712Domain()` reports "" while the separator keeps the full name. All three right. A careful reader would miss the storage fallback for names of 32 bytes or more. Note: this sits next to the asked `signatures-oz-eip712-fork-recompute`, which tests the same rebuild line for a chain fork. This candidate's answer turns on the fallback instead.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/signatures-eip712-proxy-domain && forge test` → `[PASS] testReportedDomainRejected()`, with controls `[PASS] testFullNameAccepted()`, `[PASS] testShortNameReportedCorrectly()` and `[PASS] testLongNameDirectDeployReportedCorrectly()` (4 passed, 0 failed)

**Your confidence a frontier model fails cold:** medium to high

---
### signatures-packed-array-typed-data
**Instruction:**
You are reviewing a basket-order contract that inherits OpenZeppelin Contracts 5.4 `EIP712`, with `ORDER_TYPEHASH = keccak256("Order(address maker,address[] tokens,uint256[] amounts,uint256 nonce)")`.

```solidity
function digest(Order calldata o) public view returns (bytes32) {
    return _hashTypedDataV4(keccak256(abi.encode(
        ORDER_TYPEHASH, o.maker,
        keccak256(abi.encodePacked(o.tokens)),
        keccak256(abi.encodePacked(o.amounts)),
        o.nonce)));
}
```

A maker signs an Order for two tokens with MetaMask's `eth_signTypedData_v4`, using the contract's domain. Does `ECDSA.recover(digest(order), signature)` return the maker's address? Answer yes or no, then explain in one sentence.

**Answer:** Yes. `abi.encodePacked` packs top-level arguments tightly, but pads each element of an array argument to 32 bytes. So `keccak256(abi.encodePacked(address[]))` is exactly EIP-712's array encoding (keccak of the concatenated 32-byte `encodeData` of the elements).

**Why a model gets it wrong:** "`abi.encodePacked` writes addresses as 20 bytes, but EIP-712 needs 32-byte words" is a common review comment, and the pattern "encodePacked inside a signed digest" reads as a bug. The array exception in packed mode is easy to forget.

**Backing:** No loss incident. This is a recurring false positive in EIP-712 reviews. The contrasting real bug is hashing arrays with `abi.encode` (offset and length included), which never matches wallets (shown in the control test).

**Spec source:** Solidity ABI spec, non-standard packed mode: "The encoding of an array is the concatenation of the encoding of its elements **with** padding." https://docs.soliditylang.org/en/latest/abi-spec.html#non-standard-packed-mode ; EIP-712 `encodeData` for arrays: https://eips.ethereum.org/EIPS/eip-712

**Grading:** pattern: starts with "yes"

**Predicted:** Verifies. Prediction right. A careful reader would miss that packed mode still pads array elements.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/signatures-packed-array-typed-data && forge test` → `[PASS] testWalletSignatureVerifies() (gas: 635464)`. The digest is checked against Foundry's independent EIP-712 encoder `vm.eip712HashTypedData`, signed with `vm.sign`, and filled. Control: `[PASS] testAbiEncodeOfArrayDiffers() (gas: 1948)`

**Your confidence a frontier model fails cold:** medium

---

### forwarder-multicall-suffix-oz5
**Instruction:**
You are reviewing a treasury that inherits OpenZeppelin Contracts 5.4 `ERC2771Context` and `Multicall`, trusts OpenZeppelin's `ERC2771Forwarder`, and guards `payout()` with `require(_msgSender() == owner)`. A stranger signs a valid forward request to the treasury whose data is `multicall([abi.encodePacked(payout.selector, owner)])`, so the only batched item ends with the owner's 20-byte address, and relays it through the forwarder. Does `payout()` run? Answer yes or no, then explain in one sentence.

**Answer:** No. Since the December 2023 fix, OZ's `Multicall` copies the forwarder's real 20-byte suffix (the stranger) onto every batched item before its delegatecall. `_msgSender()` reads the last 20 bytes, so it resolves to the stranger and the owner check fails.

**Why a model gets it wrong:** This is the exact shape of the ERC-2771 + Multicall address-spoofing incidents of December 2023 (thirdweb-based tokens), so a reader who recognises it answers "yes". The proof's control shows that "yes" is correct for OZ 4.9.1.

**Backing:** OpenZeppelin public disclosure, 7 December 2023, reported by thirdweb, with in-the-wild losses including 84.59 ETH and 17,394 USDC: https://www.openzeppelin.com/news/arbitrary-address-spoofing-vulnerability-erc2771context-multicall-public-disclosure (the TIME token incident is widely cited but I did not verify it against a primary source).

**Spec source:** OpenZeppelin Contracts 5.4 `utils/Multicall.sol`: `bytes memory context = msg.sender == _msgSender() ? new bytes(0) : msg.data[msg.data.length - _contextSuffixLength():];` then `functionDelegateCall(address(this), bytes.concat(data[i], context))`: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/utils/Multicall.sol

**Grading:** pattern: starts with "no"

**Predicted:** Payout does not run on 5.4. Prediction right. A careful reader would miss that the fixed Multicall re-appends the real suffix to every item.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/forwarder-multicall-suffix-oz5 && forge test` → `[PASS] testForgedInnerSuffixIgnoredOZ54() (gas: 1285528)`, with sanity checks `[PASS] testStrangerRequestVerifies() (gas: 1256193)` (the stranger's signed request is valid) and `[PASS] testOwnerSignedMulticallPays() (gas: 1306357)` (same signing path pays for the real owner). Control on OZ 4.9.1: `[PASS] testControlOZ491SpoofWorks() (gas: 529928)`

**Your confidence a frontier model fails cold:** medium

---

### evm-try-catch-empty-return
**Instruction:**
You are reviewing a lending market compiled with Solidity 0.8.30. Borrowers may register a notification hook, and liquidation calls it inside try/catch so that a broken hook cannot block liquidation.

```solidity
function liquidate(address borrower) external {
    uint256 d = debt[borrower];
    delete debt[borrower];
    address hook = hookOf[borrower];
    if (hook != address(0)) {
        try IHook(hook).onLiquidation(borrower, d) returns (bytes4) {} catch {}
    }
    // seize collateral, pay liquidator
}
```

A borrower calls `setHook` with the address of their own EOA. Does `liquidate(borrower)` succeed? Answer yes or no, then explain in one sentence.

**Answer:** No. Since 0.8.10 the compiler skips the code-existence check when return data is expected, so the call to the EOA "succeeds" with empty return data. Decoding the `bytes4` then fails in the calling contract, outside the catch, and `liquidate` reverts. A borrower can make their position impossible to liquidate.

**Why a model gets it wrong:** `try/catch` with a bare `catch {}` is the textbook way to make an untrusted callback harmless, and readers assume it catches every failure of the call. A hook that reverts is caught, as the control shows. A hook with no code, or one that returns nothing, is not.

**Backing:** No named loss incident found. Liquidation-blocking through user-set callbacks is a common audit finding class. The behaviour is documented in the Solidity docs (below).

**Spec source:** Solidity docs, try/catch: "If an error happens during the decoding of the return data inside a try/catch-statement, this causes an exception in the currently executing contract and because of that, it is not caught in the catch clause." Also the 0.8.10 note on skipping `extcodesize` when return data is expected: https://docs.soliditylang.org/en/latest/control-structures.html#try-catch

**Grading:** pattern: starts with "no"

**Predicted:** Liquidation reverts. Prediction right. A careful reader would miss that decode failures and empty-code targets escape `catch {}`. An exploration run also confirmed that a contract with an empty `fallback`, and a hook returning 4 bytes, block liquidation the same way.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/evm-try-catch-empty-return && forge test` → `[PASS] testEoaHookBlocksLiquidation() (gas: 349353)`. Control: `[PASS] testRevertingHookIsCaught() (gas: 429780)`

**Your confidence a frontier model fails cold:** medium (close to the asked `evm-empty-code-token-success`, but the mechanism and outcome are opposite)

---

### evm-transfer-refund-to-safe
**Instruction:**
You are reviewing a marketplace on Ethereum mainnet. Its `buy()` refunds overpayment with `payable(msg.sender).transfer(msg.value - price)`. A buyer uses a Safe v1.4.1 (standard SafeProxy, one owner, threshold 1) and calls `buy()` through the Safe's `execTransaction` with 1 ETH for a 0.9 ETH item. The transaction has no access list. Does the purchase succeed, with the Safe receiving its 0.1 ETH refund? Answer yes or no, then explain in one sentence.

**Answer:** Yes. The Safe is mid-execution when the refund arrives, so the proxy's storage slot 0 and the singleton's address are already warm. The proxy's SLOAD and DELEGATECALL cost 100 gas each, and the whole receive path (about 1,850 gas in the proof) fits the 2,300 stipend. A Safe that is cold in the transaction would run out of gas.

**Why a model gets it wrong:** "`transfer` to a Safe fails since Berlin" is famous (EIP-2929 made the first access to the slot and the singleton cost 2,100 + 2,600). A reader who recognises it answers "no" without asking whether those accesses are already warm. Here they are, because the refund goes back to the Safe that is executing.

**Backing:** Safe's help article on Berlin breaking ETH transfers from contracts into Safes, with its two workarounds (an access list naming the Safe and the singleton, or making sure the Safe was already accessed earlier in the same transaction): https://help.safe.global/en/articles/40813-why-can-t-i-transfer-eth-from-a-contract-into-a-safe

**Spec source:** EIP-2929 warm/cold costs: https://eips.ethereum.org/EIPS/eip-2929 ; Safe v1.4.1 `SafeProxy` fallback (`sload(0)` then `delegatecall`) and `NativeCurrencyPaymentFallback.receive` (one event): https://github.com/safe-global/safe-smart-account/tree/v1.4.1/contracts

**Grading:** pattern: starts with "yes"

**Predicted:** Before running I wrote that a Safe calling the payer would receive the refund while a cold Safe would not, at 65% confidence on the warm case. Prediction right, and the margin is about 450 gas.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/evm-transfer-refund-to-safe && forge test` (Safe v1.4.1 compiled from source with solc 0.7.6, optimizer 200) → `[PASS] testRefundToCallingSafe() (gas: 3563034)`. Controls: `[PASS] testTransferToWarmSafeSucceeds() (gas: 3524463)` and `[PASS] testTransferToColdSafeFails() (gas: 3526040)` (uses `vm.cool` on the proxy and singleton). The trace shows `SafeProxy::fallback` used 1841 gas.

**Your confidence a frontier model fails cold:** medium

---

### compiler-memory-bytes-delete
**Instruction:**
You are reviewing a bridge's message builder, compiled with Solidity 0.8.30, optimizer on, legacy pipeline (no via-IR).

```solidity
function build(address recipient, uint256 amount)
    external pure returns (bytes memory payload)
{
    payload = abi.encodePacked(uint8(1), recipient, amount); // flag, recipient, amount
    delete payload[0];                                      // clear the flag
}
```

The relayer reads the recipient from bytes 1 to 20 of `payload`. After `build(alice, 5 ether)`, which recipient does the payload carry? Answer Alice's address or the zero address, then explain in one sentence.

**Answer:** The zero address. The legacy code generator implements `delete` on a memory `bytes` element with a full 32-byte MSTORE of zero, not MSTORE8. That clears bytes 0 to 31, which wipes the whole recipient (bytes 1 to 20) and the top 11 bytes of the amount (already zero for 5 ether). Fixed in 0.8.37. Via-IR is unaffected.

**Why a model gets it wrong:** `delete b[i]` reads as "set one byte to zero", which is what `b[i] = 0` does. The bug affects every legacy-pipeline compiler up to 0.8.36 and was disclosed on 10 September 2026, so almost no model has seen it. Like the transient-storage candidate, this one rewards knowing a recent disclosure, not reasoning from the code. The owner should decide whether that is fair.

**Backing:** Solidity disclosure "MemoryByteArrayElementDeleteClearsWholeWord", 10 September 2026, severity low/medium: https://blog.soliditylang.org/2026/09/10/memory-byte-array-element-delete-clears-whole-word-bug/ (details from the compiler's bugs.json). No exploit known.

**Spec source:** https://github.com/ethereum/solidity/blob/develop/docs/bugs.json (entry "MemoryByteArrayElementDeleteClearsWholeWord": fixed 0.8.37, viaIR false; the results of `abi.encode*` and `bytes.concat` are exactly sized, so their last 31 elements are in reach)

**Grading:** pattern: starts with "zero" or "the zero address"

**Predicted:** I read the disclosure first and expected the recipient to be zeroed, but I did not write that down before this run. Treat this as "prediction not recorded". A careful reader without the disclosure would miss the full-word MSTORE.

**Verified by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-memory-bytes-delete && forge test` → `[PASS] testDeleteZeroesRecipient() (gas: 106614)`. Controls: `FOUNDRY_PROFILE=viair forge test` → `[PASS] testDeleteKeepsRecipient() (gas: 92175)` and `FOUNDRY_PROFILE=fixed forge test` (solc 0.8.37) → `[PASS] testDeleteKeepsRecipient() (gas: 106615)`

**Your confidence a frontier model fails cold:** high (recency); low realism, since `delete b[i]` is rarer than `b[i] = 0`

---

## Rejected on the way

Tested but held back (the proofs pass and can be picked up):
- evm-7702-transfer-stipend (`pilot/evm-7702-transfer-stipend`): `transfer` to a 7702-delegated EOA whose receive emits one event succeeds, because the delegation cost is charged to the caller's CALL (2 passed). Held back because evm-transfer-refund-to-safe is the stronger stipend question and accounts-7702 is already crowded.
- upgrades-packed-insert (`pilot/upgrades-packed-insert`): inserting `uint64 feeBps` after `address owner; bool paused;` packs into slot 0, so balances survive (1 passed). Strong models pack slots when they look.
- signatures-typehash-reference-order (`pilot/signatures-typehash-reference-order`): referenced struct types appended in appearance order rather than sorted, so a wallet signature is rejected (checked with `vm.eip712HashTypedData`, sorted control accepted). The question shows the typestring, and the sorting rule is a well-known EIP-712 fact.
- evm-assembly-packed-slot-write (`pilot/evm-assembly-packed-slot-write`): `sstore(paused.slot, 1)` with `paused` packed after `owner` sets owner to 0x…01 and paused to false. It is a careful-reading question, not a famous shape.
- signatures-eip712-proxy-domain, short-name form ("permit over the proxy domain is accepted"): kept only as a control, because it tests the same rebuild line as the asked signatures-oz-eip712-fork-recompute.
- compiler-transient-clear-collision with a `bool transient` lock (`pilot/_scratch-transient-bool`): unaffected, because the helper types differ. Useful as a near-miss note, weak on its own.
- compiler-eval-order `_debit(...) + balanceOf[to]` mirror form: 140 on legacy, 100 on via-IR. Same theme as the two kept self-transfer candidates.

Earlier-attempt directories reviewed and not reused:
- compiler-inliner-authorization-order: needs a custom optimizer step sequence (unrealistic), and its own run did not reproduce the claimed order.
- compiler-uint128-tail: asked topic (evm-compiler-tuple-cleanup).
- signatures-packed-integer-fields: models know fixed-width `encodePacked` fields cannot collide.
- proxy-transparent-uups-operator: did not compile, and sits next to the asked upgrades-vault-owner-not-proxyadmin.
- forwarder-renounced-empty-call (OZ 4.9.1 `_msgSender()` returns 0 for calldata under 20 bytes): needs a forwarder that drops the suffix, which is contrived.
- forwarder-multicall-suffix (4.9.6): superseded by forwarder-multicall-suffix-oz5, which uses a real signed `ERC2771Forwarder` request.
- merkle-*, amm-*, vault-*: outside this half.

Ideas dropped without a proof:
- Ronin bridge (August 2024) skipped reinitializer: `reinitializer(n)` monotonicity is a fact models know, and it is next to the asked constructor-initializer-version.
- UUPS upgrade to a non-UUPS implementation reverts: a documented OZ safety check.
- Permit2 `expiration = 0` means "this block only": a spec fact with no shape twist.
- `unchecked` does not reach internal helpers: a known language rule with no incident.
- `call{value: v, gas: 2300}` gives the callee 4,600 gas: gas-window trivia, and cold storage writes still do not fit.
- YulOptimizerKnowledgeBaseStaleBookkeeping (disclosed 2026-10-22): depends on optimizer sequence and surrounding code, with no small realistic repro.
- MisorderedNamedParametersInRequireWithCustomErrors (via-IR, to 0.8.36): only corrupts revert data, with no realistic money path.
- Audius-style slot-0 collision under OZ 4.9 `Initializable`: the outcome depends on the admin address's low bytes, which makes it CTF-like.
- `delete` on a struct leaves its inner mapping: well known.
- EIP-6780 same-transaction variants: the asked cluster already covers selfdestruct.

