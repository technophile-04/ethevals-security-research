---
author: claude-code
created: 2026-10-29
tags: [proposal, ethevals, security]
---

# security quizzes: the candidates

Each quiz below opens with the line Shiv chose, "You are an expert security researcher and smart contract auditor." Results below are from the screens without that line; the re-screen with it is running and this note will be refreshed. Numbers and process are in [[security-quizzes]].
1 meet the full bar (an open model and a frontier model miss), 21 meet the dapp-dev bar (an open model misses).


## accounts-4337-unused-gas-penalty

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a verifying paymaster for EntryPoint v0.7. It signs any user operation from the app's users with callGasLimit up to 5,000,000 and pays from its EntryPoint deposit. A typical operation uses about 150,000 gas in execution. A bundler can register as an app user, submits its own operations with callGasLimit set to 5,000,000 each time, and keeps the fees. Is the paymaster charged only for the gas each operation actually used? Answer yes or no, then explain in one sentence.

**key:** No. Starting in v0.7 the EntryPoint adds a penalty of 10% of the unused execution and postOp gas limit, here about 485,000 gas per operation. It comes out of the paymaster's deposit and goes to the bundler, so the paymaster must cap gas limits and price the penalty into what it charges.

**why it matters:** Osec (2 Dec 2025): SEND Protocol's TokenPaymaster prefund "does not account for gas penalties", and "a bundler could submit their own UserOperation ... and profit". https://osec.io/blog/2025-12-02-paymasters-evm

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | right | **missed** |

**bar:** open model miss

## accounts-1271-permit2-cross-account-replay

> You are an expert security researcher and smart contract auditor.
> 
> You are auditing a smart account factory. Each account verifies signatures like this:
> ```solidity
> function isValidSignature(bytes32 hash, bytes calldata sig) external view returns (bytes4) {
>     return ECDSA.recover(hash, sig) == owner ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
> }
> ```
> A user controls two accounts from this factory with the same owner key. Both hold USDC and neither has used Permit2 before. The user signs a Permit2 PermitSingle letting a spender take USDC from account A. Can the spender submit that same signature to Permit2 to get an allowance on account B? Answer yes or no, then explain in one sentence.

**key:** Yes. PermitSingle has no owner field, the Permit2 domain is the same for both accounts, both nonces are 0, and B checks the raw hash against the same key without binding it to B's address. The fix is defensive rehashing such as ERC-7739.

**why it matters:** - Alchemy's ERC-1271 signature replay disclosure: found 27 Oct 2023 (curiousapple had found it a month earlier). It affected LightAccount and OKX SmartAccount, with Permit2 and CoW Swap at risk. https://www.alchemy.com/blog/erc-1271-signature-replay-vulnerability
- Trail of Bits, mistake 4 in "Six mistakes in ERC-4337 smart accounts" (2026). https://blog.trailofbits.com/2026/03/11/six-mistakes-in-erc-4337-smart-accounts/

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | right | **missed** |

**bar:** open model miss

## accounts-7739-typeddatasign-domain

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a smart account's ERC-7739 isValidSignature. A dapp asks the account's owner to sign an EIP-712 Order under the dapp's own domain, and the account verifies it through the TypedDataSign workflow. In the final digest the owner's key signs, which domain separator comes right after the 0x1901 prefix: the dapp's or the account's? Answer dapp or account, then explain in one sentence.

**key:** The dapp's. The digest is keccak256(0x1901 ‖ APP_DOMAIN_SEPARATOR ‖ hashStruct(TypedDataSign{contents, the account's name, version, chainId, verifyingContract, salt})), so the account's domain fields sit inside the struct. Only the PersonalSign workflow puts the account's own domain separator in the outer position.

**why it matters:** ERC-7739 was written in response to the 2023 ERC-1271 cross-account replay disclosure and the blind-signing problem of the first fixes. https://www.alchemy.com/blog/erc-1271-signature-replay-vulnerability

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | **missed** | **missed** |

**bar:** open model miss

## accounts-safe-guard-module-path

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a treasury Safe on v1.4.1. The owners set a transaction guard with setGuard that blocks any transfer over 100 ETH, and they enabled a third-party module for recurring payroll. If the module's operator key is compromised, does the guard stop the attacker from moving 5,000 ETH out through execTransactionFromModule? Answer yes or no, then explain in one sentence.

**key:** No. In v1.4.1, execTransactionFromModule only checks that the caller is an enabled module, then executes without any guard call. Even in v1.5.0 (3 Jul 2025), module calls go through a separate module guard set with setModuleGuard, not the transaction guard.

**why it matters:** No named loss found. Safe's own code warns: "A malicious module can completely takeover a Safe." Weak incident backing. An open variant asks the same question about v1.5.0 with only setGuard configured; the answer is still no.

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | right | **missed** |

**bar:** open model miss

## signatures-oz-ecdsa-signature-as-key

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a vault's withdrawal-voucher flow before launch. An offchain service signs vouchers with one EOA key, `signer`.
> 
> ```solidity
> using ECDSA for bytes32; // OpenZeppelin Contracts 5.x
> mapping(bytes32 => bool) public used;
> 
> function claim(uint256 amount, bytes calldata sig) external {
>     bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(CLAIM_TYPEHASH, msg.sender, amount)));
>     require(digest.recover(sig) == signer, "bad sig");
>     require(!used[keccak256(sig)], "used");
>     used[keccak256(sig)] = true;
>     token.transfer(msg.sender, amount);
> }
> ```
> 
> Can a user holding one valid voucher claim it twice by changing the signature bytes? Answer yes or no, then explain in one sentence.

**key:** No. OpenZeppelin 5.x's bytes overload of recover accepts only 65-byte signatures (so the EIP-2098 short form is rejected) and rejects s above n/2 (so the (r, n−s, v') twin is rejected), which leaves one accepted encoding per signature.

**why it matters:** OpenZeppelin advisory GHSA-4h98-2769-gh6h / CVE-2022-35961 (Aug 18 2022). ECDSA.recover in versions 4.1.0 to 4.7.2 accepted both 65- and 64-byte forms, which bypassed exactly this "mark signature as used" pattern; fixed in 4.7.3; no exploit known. https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-4h98-2769-gh6h

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | right | **missed** |

**bar:** open model miss

## signatures-safe-legacy-domain-cross-chain

> You are an expert security researcher and smart contract auditor.
> 
> A DAO runs a Safe at the same address on Ethereum and on another EVM chain. Both copies were deployed from the same factory with the same setup, both use the Safe v1.1.1 singleton, and both have the same owners, threshold and current nonce. The signers collect signatures on Ethereum for an execTransaction that calls swapOwner to replace one signer, and it executes there. Can anyone submit those same signatures to the Safe on the other chain and perform the same owner swap? Answer yes or no, then explain in one sentence.

**key:** Yes. Before v1.3.0, Safe's domain separator was keccak256(abi.encode(keccak256("EIP712Domain(address verifyingContract)"), this)) with no chainId, so the safeTxHash is the same on both chains; chainId entered the domain in v1.3.0.

**why it matters:** I found no named loss from replaying Safe signatures. Related cases: Wintermute/Optimism, June 2022, 20M OP, where a Safe address existed on a second chain under someone else's control after a replayed factory deployment (https://slowmist.medium.com/slowmist-key-to-the-theft-of-20-million-op-tokens-transaction-replay-490baaf45f26), and the Code4rena Brahma (Oct 2023) finding "Signed data may be usable cross-chain" on Safe-based guards (https://vulners.com/code423n4/CODE423N4:2023-10-BRAHMA-FINDINGS-ISSUES-335). The backing is weak; the owner should decide.

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | right | **missed** |

**bar:** open model miss

## signatures-weth-phantom-permit

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a router on Ethereum mainnet that many users have approved for unlimited WETH (the canonical WETH9 contract). Its depositWithPermit(token, owner, value, deadline, v, r, s, recipient) calls IERC20Permit(token).permit(owner, address(this), value, deadline, v, r, s), then token.transferFrom(owner, address(this), value), then credits recipient. An attacker calls it with token = WETH, a victim as owner, random bytes for v, r and s, and themselves as recipient. Can the attacker take the victim's WETH this way? Answer yes or no, then explain in one sentence.

**key:** Yes. WETH9 has no permit function; its fallback runs deposit() with msg.value 0 and does not revert, so the "permit" silently succeeds and transferFrom then uses the victim's standing approval.

**why it matters:** Multichain (AnySwap) phantom-permit disclosure, Jan 10 2022; Dedaub estimated $431M of WETH at risk on Ethereum: https://dedaub.com/blog/phantom-functions-and-the-billion-dollar-no-op/ . I did not verify the amount actually stolen before the patch.

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | right | **missed** |

**bar:** open model miss

## signatures-permit2-signaturetransfer-frontrun

> You are an expert security researcher and smart contract auditor.
> 
> A user calls a vault's depositWithPermit2 and passes a Uniswap Permit2 PermitTransferFrom signature. The vault calls Permit2's permitTransferFrom to pull the tokens to itself. A searcher copies the signature and permit data from the public mempool, then calls permitTransferFrom on Permit2 directly, earlier in the block, with transferDetails.to set to the searcher's own address. Does the searcher's call move the user's tokens? Answer yes or no, then explain in one sentence.

**key:** No. When hashing PermitTransferFrom, SignatureTransfer puts msg.sender in the spender field, so the searcher's call produces a different digest and fails; only the vault can use the signature.

**why it matters:** 2024 permit-frontrunning reports, Immunefi Puffer #28702 (Feb 2024) and ZeroLend #29244 (Mar 2024): https://reports.immunefi.com/puffer-finance/28702-sc-insight-malicious-users-can-frontrun-permits-to-dos-swaps . Those cover EIP-2612 griefing; with SignatureTransfer the frontrunner cannot even use up the nonce.

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | **missed** | right |

**bar:** open model miss

## upgrades-v5-proxyadmin-constructor

> You are an expert security researcher and smart contract auditor.
> 
> Can the Safe upgrade this new vault through its existing ProxyAdmin? You are reviewing a deployment script that uses unmodified OpenZeppelin Contracts 5.2.0. It calls `new TransparentUpgradeableProxy(implementation, address(existingProxyAdmin), initData)`. The Safe owns `existingProxyAdmin`, which exposes only the standard ProxyAdmin functions. Initialization succeeds and cannot change upgrade authority. Answer yes or no, then explain in one sentence.

**key:** No. The proxy creates another ProxyAdmin owned by existingProxyAdmin, whose standard interface cannot forward the required owner call.

**why it matters:** Guardian's Citrea Stablecoin Bridge audit, September 29, 2025, L-01, disclosed missing ProxyAdmin ownership configuration and explained this constructor change; no loss reported. The nested-ProxyAdmin example isolates the same changed parameter semantics. https://www.guardian.security/portfolio/citrea/stablecoin-bridge-2025-09-29/

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | right | **missed** |

**bar:** open model miss

**fact-check:** ambiguous. Yes is defensible if the implementation exposes a UUPS `upgradeToAndCall` authorized for existingProxyAdmin, because [non-admin calls reach the implementation](https://docs.openzeppelin.com/contracts/5.x/api/proxy#transparent-vs-uups-proxies). No holds for the nested-admin path alone; exclude implementation-level upgrade paths and flag these version-specific library semantics against the brief's library-independence rule.

## upgrades-v56-empty-initialization

> You are an expert security researcher and smart contract auditor.
> 
> Does this deployment succeed with empty initialization data? You are reviewing an Ethereum vault launch using unmodified OpenZeppelin Contracts 5.6.0. The script calls `new ERC1967Proxy(address(implementation), bytes(""))` and plans to initialize the proxy in its next transaction. The implementation has valid code, the constructor receives no ETH, and no contract overrides `_unsafeAllowUninitialized`. Answer yes or no, then explain in one sentence.

**key:** No. Version 5.6.0 rejects empty initialization data during construction unless the new opt-out hook allows it.

**why it matters:** USPD's preliminary post-mortem describes a September 16, 2025 proxy-initialization hijack, exploited on December 4, 2025. The candidate asks about a later library defense, not USPD's deployed library version. https://uspd.io/blog/cpimp-attack-postmortem

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | **missed** | right |

**bar:** open model miss

## evm-compiler-assembly-write-removal

> You are an expert security researcher and smart contract auditor.
> 
> Does this helper reliably return 66 in a vault compiled with Solidity 0.8.14, the legacy pipeline, and the Yul optimizer enabled?
> ```solidity
> function marker() external pure returns (uint256 x) {
>     assembly { mstore(0, 66) }
>     assembly { x := mload(0) }
> }
> ```
> You are checking whether the vault can trust its assembly scratch-memory helpers before launch. Answer yes or no, then explain in one sentence.

**key:** No. The affected optimizer removes the first block's memory write, so this helper returns zero.

**why it matters:** Solidity's June 15, 2022 security alert follows John Toman's report; versions 0.8.13 and 0.8.14 are affected. No production loss claimed. https://www.soliditylang.org/blog/2022/06/15/inline-assembly-memory-side-effects-bug/

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | right | **missed** |

**bar:** open model miss

## evm-vyper-cross-function-lock

> You are an expert security researcher and smart contract auditor.
> 
> Does the shared `@nonreentrant("lock")` annotation prevent a callback from `withdraw` from entering `deposit` in a pool compiled with Vyper 0.2.16? Both functions use that annotation, but `withdraw` sends ETH before updating the balance that `deposit` reads. You are auditing the deployed bytecode's protection, not proposing a source rewrite. Answer yes or no, then explain in one sentence.

**key:** No. This compiler version assigns separate lock slots to the functions even when their lock names match.

**why it matters:** Vyper's critical advisory GHSA-5824-cm3x-3c38, published August 5, 2023, documents cross-function reentrancy in 0.2.15, 0.2.16 and 0.3.0; 0.3.1 fixes it. https://github.com/vyperlang/vyper/security/advisories/GHSA-5824-cm3x-3c38

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| filtered | right | right | **missed** |

**bar:** open model miss

## compiler-legacy-init-order

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing this fee vault before launch. It is compiled with Solidity 0.8.30, optimizer on, legacy pipeline (no via-IR). `Ownable` is OpenZeppelin Contracts 5.4.
> 
> ```solidity
> contract FeeVault is Ownable {
>     address public feeRecipient = owner();
> 
>     constructor() Ownable(msg.sender) {}
> 
>     function collectFees() external {
>         payable(feeRecipient).transfer(address(this).balance);
>     }
> }
> ```
> 
> Alice's EOA deploys it. Right after deployment, what does `feeRecipient()` return? Answer Alice's address or the zero address, then explain in one sentence.

**key:** The zero address. The legacy pipeline runs every state-variable initializer in the hierarchy before any constructor, so `owner()` still reads 0 when `feeRecipient` is set, and `Ownable`'s constructor only sets `_owner` afterwards. (Under via-IR the same source gives Alice's address.)

**why it matters:** No money-loss incident found. The Solidity docs list this as a semantic difference between the pipelines, with the same `y = f()` pattern: https://docs.soliditylang.org/en/latest/ir-breaking-changes.html#state-variable-initialization-order

**proved by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-legacy-init-order && forge test` → `[PASS] testLegacyFeeRecipientIsZero() (gas: 387894)`. Contrast: `FOUNDRY_PROFILE=viair forge test` → `[PASS] testViaIRFeeRecipientIsDeployer() (gas: 398491)`

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | **missed** | **missed** |

**bar:** open model miss

## compiler-eval-order-self-transfer

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing this token, compiled with Solidity 0.8.30, optimizer on, legacy pipeline (no via-IR).
> 
> ```solidity
> mapping(address => uint256) public balanceOf;
> 
> function transfer(address to, uint256 amount) external {
>     balanceOf[to] = balanceOf[to] + _debit(msg.sender, amount);
> }
> 
> function _debit(address from, uint256 amount) internal returns (uint256) {
>     balanceOf[from] -= amount;
>     return amount;
> }
> ```
> 
> Alice holds 100 tokens and calls `transfer(alice, 40)`, sending to herself. What is `balanceOf(alice)` afterwards? Answer with the number only.

**key:** 100. The legacy code generator evaluates the right operand of `+` first, so `_debit` runs (100 → 60) before `balanceOf[to]` is read (60), and 60 + 40 = 100. The same source compiled via-IR evaluates left to right, reads 100 before the debit, and ends at 140.

**why it matters:** Super Sushi Samurai, 21 March 2024, about $4.8M: self-transfers doubled the attacker's balance because both balances were read before either write (https://blog.solidityscan.com/super-sushi-samurai-hack-analysis-ae96b76a6252/; team post-mortem not checked).

**proved by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-eval-order-self-transfer && forge test` → `[PASS] testSelfTransferLegacy() (gas: 151020)`. Contrast: `FOUNDRY_PROFILE=viair forge test` → `[PASS] testSelfTransferViaIR() (gas: 113991)`. Also passes with `FOUNDRY_OPTIMIZER=false`.

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| filtered | right | **missed** | **missed** |

**bar:** open model miss

## compiler-tuple-assignment-self-transfer

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing this token, compiled with Solidity 0.8.30, optimizer on.
> 
> ```solidity
> mapping(address => uint256) public balanceOf;
> 
> function transfer(address to, uint256 amount) external {
>     uint256 fromBal = balanceOf[msg.sender];
>     uint256 toBal = balanceOf[to];
>     require(fromBal >= amount, "balance");
>     (balanceOf[msg.sender], balanceOf[to]) = (fromBal - amount, toBal + amount);
> }
> ```
> 
> Alice holds 100 tokens and calls `transfer(alice, 40)`, sending to herself. What is `balanceOf(alice)` afterwards? Answer with the number only.

**key:** 60. Both sides of the tuple are computed from the cached balances (60, 140). Solidity then writes the components from right to left, so `balanceOf[to] = 140` is written first and `balanceOf[msg.sender] = 60` overwrites it. Alice loses 40 tokens.

**why it matters:** Super Sushi Samurai, 21 March 2024, about $4.8M: self-transfers inflated balances through cached reads (https://blog.solidityscan.com/super-sushi-samurai-hack-analysis-ae96b76a6252/). This tuple form deflates instead, so here the loss falls on the sender (a user who sends to themselves, or any flow that routes funds through `to == from`).

**proved by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-tuple-assignment-self-transfer && forge test` → `[PASS] testSelfTransferEndsAt60() (gas: 156605)`, `[PASS] testNormalTransfer() (gas: 179399)`. Also `FOUNDRY_PROFILE=viair forge test` → `[PASS] testSelfTransferEndsAt60() (gas: 128925)`. `forge test --use 0.8.20|0.8.24|0.8.33` on both profiles and `FOUNDRY_OPTIMIZER=false forge test` all pass (see run.log).

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | **missed** | **missed** |

**bar:** open model miss

## compiler-transient-clear-collision

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing this vault, compiled with Solidity 0.8.33, via-IR, optimizer on, EVM version cancun. `Ownable2Step` is OpenZeppelin Contracts 5.4.
> 
> ```solidity
> contract Vault is Ownable2Step {
>     address transient activeCaller;
> 
>     constructor() Ownable(msg.sender) {}
> 
>     function run() external {
>         activeCaller = msg.sender;
>         // ... work that reads activeCaller ...
>         delete activeCaller;
>     }
> }
> ```
> 
> The deployer calls `transferOwnership(bob)`, Bob calls `acceptOwnership()`, and later Bob calls `renounceOwnership()`. Can Bob then call `acceptOwnership()` again and become owner? Answer yes or no, then explain in one sentence.

**key:** Yes. Under the TransientStorageClearingHelperCollision bug (0.8.28 to 0.8.33, via-IR), `delete activeCaller` and Ownable2Step's `delete _pendingOwner` share one `set_to_zero` helper. In this contract the shared helper clears transient storage, so `_pendingOwner` is never cleared. Bob stays pending after accepting and after renouncing, and can accept again.

**why it matters:** Solidity disclosure, 18 February 2026, severity high: https://blog.soliditylang.org/2026/02/18/transient-storage-clearing-helper-collision-bug/ (conditions taken from the compiler's own bugs.json: https://github.com/ethereum/solidity/blob/develop/docs/bugs.json). No exploit known.

**proved by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-transient-clear-collision && forge test` → `[PASS] testBobReclaimsAfterRenounce() (gas: 226770)`. Controls: `FOUNDRY_PROFILE=fixed forge test` (solc 0.8.34) → `[PASS] testRenounceIsFinal() (gas: 183060)`. `FOUNDRY_PROFILE=legacy forge test` (0.8.33, no via-IR) → `[PASS] testRenounceIsFinal() (gas: 189773)`

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | **missed** | **missed** |

**bar:** open model miss

## upgrades-stateless-parent-gap

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a V2 upgrade of a UUPS vault built on OpenZeppelin Contracts Upgradeable 4.9.6.
> 
> ```solidity
> contract VaultV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
>     mapping(address => uint256) public balanceOf;
>     // ...
> }
> 
> contract VaultV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable, MulticallUpgradeable {
>     mapping(address => uint256) public balanceOf;
>     // ... same functions as V1
> }
> ```
> 
> V2 only appends `MulticallUpgradeable` so users can batch calls. Alice's V1 balance is 100. The owner upgrades the proxy to V2 with no migration. What does `balanceOf(alice)` return afterwards? Answer with the number only.

**key:** 0. `MulticallUpgradeable` 4.9.6 has no variables but still declares `uint256[50] private __gap`, so appending it moves `balanceOf` from slot 201 to slot 251. The owner is unaffected.

**why it matters:** No incident found. The OpenZeppelin Upgrades plugin rejects this layout change. MulticallUpgradeable 4.9.6 source: https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v4.9.6/contracts/utils/MulticallUpgradeable.sol

**proved by:** `cd /tmp/subagents/security-quizzes/pilot/upgrades-stateless-parent-gap && forge test` → `[PASS] testAppendedMulticallMovesBalances() (gas: 1699746)`. `forge inspect` shows balanceOf at slot 201 in V1 and 251 in V2.

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | **missed** | **missed** |

**bar:** open model miss

## forwarder-multicall-suffix-oz5

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a treasury that inherits OpenZeppelin Contracts 5.4 `ERC2771Context` and `Multicall`, trusts OpenZeppelin's `ERC2771Forwarder`, and guards `payout()` with `require(_msgSender() == owner)`. A stranger signs a valid forward request to the treasury whose data is `multicall([abi.encodePacked(payout.selector, owner)])`, so the only batched item ends with the owner's 20-byte address, and relays it through the forwarder. Does `payout()` run? Answer yes or no, then explain in one sentence.

**key:** No. Since the December 2023 fix, OZ's `Multicall` copies the forwarder's real 20-byte suffix (the stranger) onto every batched item before its delegatecall. `_msgSender()` reads the last 20 bytes, so it resolves to the stranger and the owner check fails.

**why it matters:** OpenZeppelin public disclosure, 7 December 2023, reported by thirdweb, with in-the-wild losses including 84.59 ETH and 17,394 USDC: https://www.openzeppelin.com/news/arbitrary-address-spoofing-vulnerability-erc2771context-multicall-public-disclosure (the TIME token incident is widely cited but I did not verify it against a primary source).

**proved by:** `cd /tmp/subagents/security-quizzes/pilot/forwarder-multicall-suffix-oz5 && forge test` → `[PASS] testForgedInnerSuffixIgnoredOZ54() (gas: 1285528)`, with sanity checks `[PASS] testStrangerRequestVerifies() (gas: 1256193)` (the stranger's signed request is valid) and `[PASS] testOwnerSignedMulticallPays() (gas: 1306357)` (same signing path pays for the real owner). Control on OZ 4.9.1: `[PASS] testControlOZ491SpoofWorks() (gas: 529928)`

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| filtered | right | right | **missed** |

**bar:** open model miss

## evm-try-catch-empty-return

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a lending market compiled with Solidity 0.8.30. Borrowers may register a notification hook, and liquidation calls it inside try/catch so that a broken hook cannot block liquidation.
> 
> ```solidity
> function liquidate(address borrower) external {
>     uint256 d = debt[borrower];
>     delete debt[borrower];
>     address hook = hookOf[borrower];
>     if (hook != address(0)) {
>         try IHook(hook).onLiquidation(borrower, d) returns (bytes4) {} catch {}
>     }
>     // seize collateral, pay liquidator
> }
> ```
> 
> A borrower calls `setHook` with the address of their own EOA. Does `liquidate(borrower)` succeed? Answer yes or no, then explain in one sentence.

**key:** No. Since 0.8.10 the compiler skips the code-existence check when return data is expected, so the call to the EOA "succeeds" with empty return data. Decoding the `bytes4` then fails in the calling contract, outside the catch, and `liquidate` reverts. A borrower can make their position impossible to liquidate.

**why it matters:** No named loss incident found. Liquidation-blocking through user-set callbacks is a common audit finding class. The behaviour is documented in the Solidity docs (below).

**proved by:** `cd /tmp/subagents/security-quizzes/pilot/evm-try-catch-empty-return && forge test` → `[PASS] testEoaHookBlocksLiquidation() (gas: 349353)`. Control: `[PASS] testRevertingHookIsCaught() (gas: 429780)`

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | **missed** | right |

**bar:** open model miss

## evm-transfer-refund-to-safe

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a marketplace on Ethereum mainnet. Its `buy()` refunds overpayment with `payable(msg.sender).transfer(msg.value - price)`. A buyer uses a Safe v1.4.1 (standard SafeProxy, one owner, threshold 1) and calls `buy()` through the Safe's `execTransaction` with 1 ETH for a 0.9 ETH item. The transaction has no access list. Does the purchase succeed, with the Safe receiving its 0.1 ETH refund? Answer yes or no, then explain in one sentence.

**key:** Yes. The Safe is mid-execution when the refund arrives, so the proxy's storage slot 0 and the singleton's address are already warm. The proxy's SLOAD and DELEGATECALL cost 100 gas each, and the whole receive path (about 1,850 gas in the proof) fits the 2,300 stipend. A Safe that is cold in the transaction would run out of gas.

**why it matters:** Safe's help article on Berlin breaking ETH transfers from contracts into Safes, with its two workarounds (an access list naming the Safe and the singleton, or making sure the Safe was already accessed earlier in the same transaction): https://help.safe.global/en/articles/40813-why-can-t-i-transfer-eth-from-a-contract-into-a-safe

**proved by:** `cd /tmp/subagents/security-quizzes/pilot/evm-transfer-refund-to-safe && forge test` (Safe v1.4.1 compiled from source with solc 0.7.6, optimizer 200) → `[PASS] testRefundToCallingSafe() (gas: 3563034)`. Controls: `[PASS] testTransferToWarmSafeSucceeds() (gas: 3524463)` and `[PASS] testTransferToColdSafeFails() (gas: 3526040)` (uses `vm.cool` on the proxy and singleton). The trace shows `SafeProxy::fallback` used 1841 gas.

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| filtered | right | **missed** | right |

**bar:** open model miss

## compiler-memory-bytes-delete

> You are an expert security researcher and smart contract auditor.
> 
> You are reviewing a bridge's message builder, compiled with Solidity 0.8.30, optimizer on, legacy pipeline (no via-IR).
> 
> ```solidity
> function build(address recipient, uint256 amount)
>     external pure returns (bytes memory payload)
> {
>     payload = abi.encodePacked(uint8(1), recipient, amount); // flag, recipient, amount
>     delete payload[0];                                      // clear the flag
> }
> ```
> 
> The relayer reads the recipient from bytes 1 to 20 of `payload`. After `build(alice, 5 ether)`, which recipient does the payload carry? Answer Alice's address or the zero address, then explain in one sentence.

**key:** The zero address. The legacy code generator implements `delete` on a memory `bytes` element with a full 32-byte MSTORE of zero, not MSTORE8. That clears bytes 0 to 31, which wipes the whole recipient (bytes 1 to 20) and the top 11 bytes of the amount (already zero for 5 ether). Fixed in 0.8.37. Via-IR is unaffected.

**why it matters:** Solidity disclosure "MemoryByteArrayElementDeleteClearsWholeWord", 10 September 2026, severity low/medium: https://blog.soliditylang.org/2026/09/10/memory-byte-array-element-delete-clears-whole-word-bug/ (details from the compiler's bugs.json). No exploit known.

**proved by:** `cd /tmp/subagents/security-quizzes/pilot/compiler-memory-bytes-delete && forge test` → `[PASS] testDeleteZeroesRecipient() (gas: 106614)`. Controls: `FOUNDRY_PROFILE=viair forge test` → `[PASS] testDeleteKeepsRecipient() (gas: 92175)` and `FOUNDRY_PROFILE=fixed forge test` (solc 0.8.37) → `[PASS] testDeleteKeepsRecipient() (gas: 106615)`

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| **missed** | right | **missed** | **missed** |

**bar:** frontier and open model miss

## evm-compiler-conditional-stop

> You are an expert security researcher and smart contract auditor.
> 
> Can this vault safely assume its first storage write survives `save(true)` when compiled with Solidity 0.8.16 and optimized via-IR?
> ```solidity
> uint256 public saved;
> function save(bool finish) external {
>     saved = 1;
>     finishEarly(finish);
>     saved = 2;
> }
> function finishEarly(bool finish) internal {
>     if (finish) { assembly { stop() } }
> }
> ```
> Assume `saved` starts at zero. Answer yes or no, then explain in one sentence.

**key:** No. The affected Yul optimizer can remove the first write despite the helper's successful early termination.

**why it matters:** Solidity's September 8, 2022 security alert reports a medium/high-severity bug introduced in 0.8.13 and fixed in 0.8.17. No production loss claimed. https://www.soliditylang.org/blog/2022/09/08/storage-write-removal-before-conditional-termination/

| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 | GLM 5.3 |
|---|---|---|---|
| right | right | right | right |

**bar:** no miss

**fact-check:** wrong. Corrected answer: Yes under the standard optimized via-IR settings; compiling this exact snippet with 0.8.16 retains `sstore(0, 1)` before STOP. The [disclosure, line 58 and its following example](https://www.soliditylang.org/blog/2022/09/08/storage-write-removal-before-conditional-termination/#which-contracts-are-affected), explicitly says "almost identical, but unaffected, since g() will be inlined", which applies to this conditional assembly helper.
