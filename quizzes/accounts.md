# Candidate quizzes: post-Pectra account semantics and smart accounts

### accounts-7702-eoa-only-flashloan
**Instruction:**
You are reviewing a staking contract on Ethereum mainnet that values each deposit at the DEX pool's spot price. The team says flash-loan price manipulation is impossible because stake() starts with `require(msg.sender == tx.origin)`, so only an EOA calling directly can stake, and an EOA cannot borrow and stake inside one transaction. After the Pectra upgrade, can an attacker take a flash loan, push the pool price, and pass this check within a single transaction? Answer yes or no, then explain in one sentence.

**Answer:** Yes. An EOA with an EIP-7702 delegation sends a transaction to itself, and its delegated code borrows, swaps and then calls stake() directly, so msg.sender and tx.origin are both the EOA.

**Why a model gets it wrong:** Models believe that tx.origin never has code, so `msg.sender == tx.origin` means "a plain keyholder with no code, making one call". Frontier models probably know EIP-7702 changed this. Open models often still treat the check as a way to block contracts.

**Backing:** A staking contract on BSC was exploited on 24 Aug 2025 for about $85K. A delegated EOA sent BNB to itself, which ran its fallback, took a $3.5M flash loan, inflated the POT price and staked. https://www.openzeppelin.com/news/the-notorious-bug-digest-5

**Spec source:** https://eips.ethereum.org/EIPS/eip-7702#backwards-compatibility ("tx.origin == msg.sender can only be true in the topmost frame of execution" is listed as a broken invariant, and "Once an account has been delegated, it can invoke multiple calls per transaction.")

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** medium

### accounts-7702-delegation-survives-revert
**Instruction:**
You are reviewing a wallet's EIP-7702 onboarding flow. A relayer sends one set code transaction (type 4) that carries the user's signed authorization for the wallet's delegate contract, and whose calldata calls initialize(owner) on the user's address. The relayer set the gas limit too low, initialize runs out of gas, and the transaction's execution reverts. Once this transaction is included in a block, does the user's address point to the delegate contract? Answer yes or no, then explain in one sentence.

**Answer:** Yes. The authorization list is processed before execution starts, and the delegation indicator is not rolled back when execution fails. The account ends up delegated but uninitialized, and its nonce has gone up.

**Why a model gets it wrong:** Models apply "a revert undoes every state change in the transaction" to the authorization as well.

**Backing:** I found no named incident. The risk is the one EIP-7702 names: an uninitialized delegated account that someone else can initialize (see the next candidate). Trail of Bits lists front-runnable initialization among its six common ERC-4337 account mistakes (11 Mar 2026). https://blog.trailofbits.com/2026/03/11/six-mistakes-in-erc-4337-smart-accounts/

**Spec source:** https://eips.ethereum.org/EIPS/eip-7702 ("if transaction execution results in failure ... the processed delegation indicators is _not rolled back_.")

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** medium

### accounts-7702-init-frontrun
**Instruction:**
You are auditing a delegate contract for EIP-7702 wallets. Its setup function is:
```solidity
function initialize(address owner) external {
    require(_owner == address(0), "already initialized");
    _owner = owner;
}
```
The wallet's relayer puts the user's authorization and a call to initialize(userOwner) in the same set code transaction, and the team argues that because both happen atomically, nobody else can set the owner first. Is this setup safe from front-running? Answer yes or no, then explain in one sentence.

**Answer:** No. The signed tuple commits only to chain_id, address and nonce, not to any calldata. Anyone who sees it in the mempool can put it in their own set code transaction with initialize(attacker) and get included first. The setup calldata has to be signed by the EOA key and checked with ecrecover, or initialize must require `msg.sender == address(this)`.

**Why a model gets it wrong:** Models treat the authorization and the call as one signed, atomic unit. In fact the outer transaction signature belongs to the relayer, and the authorization can be lifted into any other transaction.

**Backing:** I found no named loss. The pattern is mistake 6 in Trail of Bits, "Six mistakes in ERC-4337 smart accounts" (11 Mar 2026). https://blog.trailofbits.com/2026/03/11/six-mistakes-in-erc-4337-smart-accounts/

**Spec source:** https://eips.ethereum.org/EIPS/eip-7702#security-considerations ("Front running initialization": "...must verify the initial calldata to the account for setup purposes be signed by the EOA's key using ecrecover.")

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** medium

### accounts-7702-chainid-zero-revocation
**Instruction:**
You are handling a wallet incident. A user signed an EIP-7702 authorization with chain_id 0 and nonce 7, delegating their EOA to a contract that turns out to be a drainer. On Ethereum mainnet they then sent a transaction carrying a new authorization to address 0 with chain_id 1, clearing the delegation there. On Base, the same EOA's nonce is still 7, and the drainer contract is deployed at the same address. Can the attacker still use the original signed authorization to delegate the EOA on Base? Answer yes or no, then explain in one sentence.

**Answer:** Yes. An authorization with chain_id 0 is valid on any chain where the authority's nonce equals the signed nonce. The mainnet revocation only moved the mainnet nonce, so revocation has to happen chain by chain.

**Why a model gets it wrong:** Models assume that revoking a delegation, or delegating to address 0, invalidates the signed authorization everywhere. Some also assume every authorization is bound to one chain.

**Backing:** 2025 delegation phishing and sweepers. Wintermute found more than 97% of early delegations pointed to "CrimeEnjoyor" sweeper bytecode (May–June 2025). Scam Sniffer reported a $1.54M loss through a 7702 phishing batch on 24 Aug 2025. https://cointelegraph.com/news/wintermute-crimeenjoyor-flags-malicious-ethereum-contracts and https://drops.scamsniffer.io/scam-sniffer-2025-crypto-phishing-losses-fall-83-to-84-million/ **Not verified:** I found no confirmed drain that used chain_id 0 specifically.

**Spec source:** https://eips.ethereum.org/EIPS/eip-7702 ("Verify the chain ID is 0 or the ID of the current chain", "Verify the nonce of authority is equal to nonce", and in the Rationale, "When universal deployment is preferred, simply set chain ID to 0.")

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** medium

### accounts-7702-self-sponsored-nonce
**Instruction:**
You are reviewing a deploy script that upgrades the team's treasury EOA with EIP-7702. The EOA's current nonce is 41. The script has the EOA sign an authorization for the delegate contract, then the same EOA sends the set code transaction itself, with transaction nonce 41, calling setup() on its own address. What nonce must the authorization carry for the delegation to take effect? Answer with the number only.

**Answer:** 42. The sender's nonce goes up before the authorization list is processed, so when the sender is also the authority the tuple must carry the transaction nonce plus one. With 41 the tuple is skipped, and setup() runs against empty code and silently succeeds.

**Why a model gets it wrong:** Models sign with "the current nonce", which is correct when someone else sponsors the transaction. The ordering rule for self-sponsored transactions is obscure.

**Backing:** No incident. The failure leaves the treasury silently un-upgraded, without the guard logic the team thinks it has. Weak backing.

**Spec source:** https://eips.ethereum.org/EIPS/eip-7702 (the authorization list is "processed before the execution portion of the transaction begins, but after the sender's nonce is incremented.")

**Grading:** pattern: starts with 42

**Your confidence a frontier model fails cold:** high

### accounts-7702-redelegation-initializable
**Instruction:**
You are reviewing a wallet migration. A user's EOA is delegated with EIP-7702 to Wallet A, which inherits OpenZeppelin Contracts 5.x Initializable and was initialized long ago. The user now re-delegates to Wallet B, an unrelated contract from another team that also inherits OpenZeppelin Contracts 5.x Initializable and exposes `function initialize(address owner) external initializer`. Nothing clears the account's storage in between. When the user then calls initialize on their own address, does it succeed? Answer yes or no, then explain in one sentence.

**Answer:** No. The account's storage survives re-delegation. Both wallets keep `_initialized` in the same ERC-7201 slot, derived from "openzeppelin.storage.Initializable", so Wallet B reads version 1. The account has code, so the construction exception does not apply, and the call reverts with InvalidInitialization.

**Why a model gets it wrong:** Models assume a new delegate starts with fresh storage, or that ERC-7201 namespacing rules out collisions between unrelated wallets. In fact every OpenZeppelin-based contract shares OpenZeppelin's own namespace.

**Backing:** I found no named loss. EIP-7702's security considerations call re-delegation "security-critical", and ERC-7779 exists because of re-delegation storage collisions. https://eips.ethereum.org/EIPS/eip-7779 Weak incident backing.

**Spec source:** https://eips.ethereum.org/EIPS/eip-7702#security-considerations ("Storage management") and https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/proxy/utils/Initializable.sol (`INITIALIZABLE_STORAGE = 0xf0c57e16...6a00` and `construction = initialized == 1 && address(this).code.length == 0`)

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** high

### accounts-7702-delegate-unguarded-call
**Instruction:**
You are auditing a vault on Arbitrum whose admin functions use onlyAdmin, and the admin is an EOA. To compound rewards in one transaction, the ops team delegated that EOA with EIP-7702 to an in-house batching helper. The helper has `function execute(address target, bytes calldata data) external` with no caller check, because the team says only the admin's own transactions ever reach it. Can an outside account make the vault see msg.sender equal to the admin? Answer yes or no, then explain in one sentence.

**Answer:** Yes. Anyone can call the admin's address. The helper's code runs with the admin as address(this), so its call to the vault arrives with msg.sender equal to the admin.

**Why a model gets it wrong:** This is likely known, since careful reasoning gets there. A model that accepts "only our own transactions reach it" gets it wrong.

**Backing:** IPOR USDC Lending Optimizer on Arbitrum, 6 Jan 2026, about $336K. The admin EOA was delegated to a bundling helper whose "arbitrary call" function let the attacker act as admin and add a malicious fuse. https://ipor.io/news/post-mortem-ipor-usdc-optimizer-arbitrum-vault-exploit-aff11fd01b62 The post-mortem does not spell out the helper's exact authorization logic.

**Spec source:** https://eips.ethereum.org/EIPS/eip-7702 (delegated code executes in the authority's context; "The code specified by an authorization has unrestricted access to the account")

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** low

### accounts-4337-validuntil-zero
**Instruction:**
You are auditing an ERC-4337 session-key validator for EntryPoint v0.7. validateUserOp returns `_packValidationData(sigFailed, session.validUntil, session.validAfter)` for the session key that signed. To revoke a key, `revoke(key)` sets `sessions[key].validUntil = 0` and leaves the rest of the entry in place; the team says a validUntil of 0 means the key expired at the Unix epoch. After revoke, will the EntryPoint still accept user operations signed by that key? Answer yes or no, then explain in one sentence.

**Answer:** Yes. The EntryPoint turns a validUntil of 0 into type(uint48).max, meaning no expiry, so the "revoked" key is valid forever. Revocation must delete the key or make the signature check fail.

**Why a model gets it wrong:** Models carry over the deadline intuition that timestamp 0 is in the past and therefore expired, and the team's claim in the instruction pushes that way.

**Backing:** Audit-checklist pattern: an unset or zeroed validUntil gives a session key that never expires. https://dev.to/bloqarl/six-ways-erc-4337-smart-accounts-fail-in-audits-1gac This is a secondary source. I found no named loss or published audit finding. Weak backing.

**Spec source:** https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/core/Helpers.sol (`if (validUntil == 0) { validUntil = type(uint48).max; }`) and https://eips.ethereum.org/EIPS/eip-4337 ("validUntil is 6-byte timestamp value, or zero for 'infinite'")

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** medium

### accounts-4337-v07-postop-charge
**Instruction:**
You are reviewing an ERC-20 paymaster for EntryPoint v0.7 that lets users pay gas in USDC. validatePaymasterUserOp only checks the user's USDC balance and allowance and returns a context; postOp then calls `usdc.transferFrom(user, paymaster, cost)`. A user's operation calldata ends by setting the paymaster's USDC allowance to zero, so that transferFrom reverts. Who ends up paying for this operation's gas: the user or the paymaster? Answer user or paymaster, then explain in one sentence.

**Answer:** The paymaster. In v0.7 a reverting postOp reverts the operation's execution, and the EntryPoint then charges the paymaster's deposit in postOpReverted mode without calling postOp again. The paymaster pays and collects nothing. The fix is to take the maximum token cost during validation and refund the rest in postOp.

**Why a model gets it wrong:** In EntryPoint v0.6, a reverting postOp was retried in postOpReverted mode after the user's calldata had been rolled back, so charging in postOp worked. Models and tutorials still describe that behaviour.

**Backing:**
- Osec, "ERC-4337 paymasters: better UX, hidden risks" (2 Dec 2025). It flags Pimlico's SingletonPaymasterV7 post-execution charging and says the pattern "used to work in EntryPoint version v0.6, but ... no longer works in v0.7". https://osec.io/blog/2025-12-02-paymasters-evm
- Quantstamp's audit of Alchemy's ERC-4337 paymasters has a Medium finding, since fixed, that the paymaster pays for operations whose postOp reverts. https://certificate.quantstamp.com/full/alchemy-erc-4337-paymasters/26692985-f0ac-496a-afea-9e00184d0995/index.html

**Spec source:**
- v0.7: https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/core/EntryPoint.sol (`_postExecution`: `if (mode != IPaymaster.PostOpMode.postOpReverted)` then `revert PostOpReverted(reason)`; `_executeUserOp` then calls `_postExecution(postOpReverted, ...)`)
- v0.6, for contrast: https://github.com/eth-infinitism/account-abstraction/blob/v0.6.0/contracts/core/EntryPoint.sol (`_handlePostOp` retries postOp inside a `try`)

**Grading:** pattern: starts with paymaster

**Your confidence a frontier model fails cold:** medium

### accounts-4337-unused-gas-penalty
**Instruction:**
You are reviewing a verifying paymaster for EntryPoint v0.7. It signs any user operation from the app's users with callGasLimit up to 5,000,000 and pays from its EntryPoint deposit. A typical operation uses about 150,000 gas in execution. A bundler can register as an app user, submits its own operations with callGasLimit set to 5,000,000 each time, and keeps the fees. Is the paymaster charged only for the gas each operation actually used? Answer yes or no, then explain in one sentence.

**Answer:** No. Starting in v0.7 the EntryPoint adds a penalty of 10% of the unused execution and postOp gas limit, here about 485,000 gas per operation. It comes out of the paymaster's deposit and goes to the bundler, so the paymaster must cap gas limits and price the penalty into what it charges.

**Why a model gets it wrong:** Models carry the v0.6 belief that unused gas is fully refunded. The v0.7 penalty is far less widely known.

**Backing:** Osec (2 Dec 2025): SEND Protocol's TokenPaymaster prefund "does not account for gas penalties", and "a bundler could submit their own UserOperation ... and profit". https://osec.io/blog/2025-12-02-paymasters-evm

**Spec source:**
- v0.7: https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/core/EntryPoint.sol (`PENALTY_PERCENT = 10`; `unusedGasPenalty = (unusedGas * PENALTY_PERCENT) / 100`)
- v0.8 adds `PENALTY_GAS_THRESHOLD = 40000`: https://github.com/eth-infinitism/account-abstraction/blob/v0.8.0/contracts/core/EntryPoint.sol

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** medium

### accounts-4337-unstaked-paymaster-context
**Instruction:**
You are reviewing a token paymaster before launch on the ERC-4337 shared mempool. To save capital, the team will never add stake for it in the EntryPoint. Its validatePaymasterUserOp returns a non-empty context so that postOp can settle each user's token charge. Will bundlers that follow the ERC-7562 validation rules accept user operations that use this paymaster? Answer yes or no, then explain in one sentence.

**Answer:** No. ERC-7562 rule EREP-050 says an unstaked paymaster may not return a context, so a paymaster that needs postOp must be staked.

**Why a model gets it wrong:** Models know staking widens what a paymaster may read and write and affects its reputation. They don't know that returning a context requires stake at all.

**Backing:** No incident; the cost is a launch that fails or is rejected on the shared mempool. Osec's paymaster write-up and the fixes it describes assume staked token paymasters. https://osec.io/blog/2025-12-02-paymasters-evm Weak backing.

**Spec source:** https://eips.ethereum.org/EIPS/eip-7562 (EREP-050: "An unstaked paymaster may not return a context." The ERC is still in Review.)

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** high

### accounts-1271-permit2-cross-account-replay
**Instruction:**
You are auditing a smart account factory. Each account verifies signatures like this:
```solidity
function isValidSignature(bytes32 hash, bytes calldata sig) external view returns (bytes4) {
    return ECDSA.recover(hash, sig) == owner ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
}
```
A user controls two accounts from this factory with the same owner key. Both hold USDC and neither has used Permit2 before. The user signs a Permit2 PermitSingle letting a spender take USDC from account A. Can the spender submit that same signature to Permit2 to get an allowance on account B? Answer yes or no, then explain in one sentence.

**Answer:** Yes. PermitSingle has no owner field, the Permit2 domain is the same for both accounts, both nonces are 0, and B checks the raw hash against the same key without binding it to B's address. The fix is defensive rehashing such as ERC-7739.

**Why a model gets it wrong:** Models assume the EIP-712 domain or the nonce stops replay. They miss that the domain belongs to Permit2, not to the account, and that the owner isn't in the signed struct. This may be known, since it was disclosed in 2023 and Trail of Bits covered it again in 2026.

**Backing:**
- Alchemy's ERC-1271 signature replay disclosure: found 27 Oct 2023 (curiousapple had found it a month earlier). It affected LightAccount and OKX SmartAccount, with Permit2 and CoW Swap at risk. https://www.alchemy.com/blog/erc-1271-signature-replay-vulnerability
- Trail of Bits, mistake 4 in "Six mistakes in ERC-4337 smart accounts" (2026). https://blog.trailofbits.com/2026/03/11/six-mistakes-in-erc-4337-smart-accounts/

**Spec source:**
- https://github.com/Uniswap/permit2/blob/main/src/libraries/PermitHash.sol (`PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)` with no owner field)
- https://eips.ethereum.org/EIPS/eip-7739 (the Motivation section cites Permit2 and accounts that share an owner)

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** medium

### accounts-7739-typeddatasign-domain
**Instruction:**
You are reviewing a smart account's ERC-7739 isValidSignature. A dapp asks the account's owner to sign an EIP-712 Order under the dapp's own domain, and the account verifies it through the TypedDataSign workflow. In the final digest the owner's key signs, which domain separator comes right after the 0x1901 prefix: the dapp's or the account's? Answer dapp or account, then explain in one sentence.

**Answer:** The dapp's. The digest is keccak256(0x1901 ‖ APP_DOMAIN_SEPARATOR ‖ hashStruct(TypedDataSign{contents, the account's name, version, chainId, verifyingContract, salt})), so the account's domain fields sit inside the struct. Only the PersonalSign workflow puts the account's own domain separator in the outer position.

**Why a model gets it wrong:** "Defensive rehashing" suggests re-wrapping under the account's own domain, which is what the pre-7739 fixes did and which made messages unreadable to users. So models answer "account".

**Backing:** ERC-7739 was written in response to the 2023 ERC-1271 cross-account replay disclosure and the blind-signing problem of the first fixes. https://www.alchemy.com/blog/erc-1271-signature-replay-vulnerability

**Spec source:** https://eips.ethereum.org/EIPS/eip-7739 (TypedDataSign: "keccak256(\x19\x01 ‖ APP_DOMAIN_SEPARATOR ‖ ..."; PersonalSign uses ACCOUNT_DOMAIN_SEPARATOR. The ERC is a Draft.)

**Grading:** pattern: starts with dapp (also accept "the dapp's" and "application")

**Your confidence a frontier model fails cold:** high

### accounts-7579-fallback-sender
**Instruction:**
You are auditing an ERC-7579 module installed on accounts as both a fallback handler and an executor. Its fallback function `sweep(address token, address to)` checks only that msg.sender is an account with this module installed, then calls executeFromExecutor on msg.sender to send the account's whole token balance to `to`. A stranger calls sweep on a user's account address, and the account forwards it to the handler with CALL, as the standard requires. Can the stranger drain the account this way? Answer yes or no, then explain in one sentence.

**Answer:** Yes. When the account forwards a fallback call, msg.sender in the handler is the account itself. The real caller appears only in the 20 bytes the account appends under ERC-2771, so the handler must authorize on `_msgSender()`.

**Why a model gets it wrong:** Models assume the handler sees the original caller as msg.sender, or that the account's own owner checks cover fallback routes. They don't: the standard leaves authorization on those routes to the handler or to hooks.

**Backing:** No named incident found. The ERC-7579 security considerations warn that "Insufficient authorization control in fallback handlers can lead to unauthorized executions." Weak incident backing.

**Spec source:** https://eips.ethereum.org/EIPS/eip-7579 ("MUST utilize ERC-2771 to add the original msg.sender to the calldata sent to the fallback handler" and "MUST NOT rely on msg.sender for authorization control but MUST use ERC-2771 _msgSender() instead". The ERC is a Draft.)

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** medium

### accounts-safe-guard-module-path
**Instruction:**
You are reviewing a treasury Safe on v1.4.1. The owners set a transaction guard with setGuard that blocks any transfer over 100 ETH, and they enabled a third-party module for recurring payroll. If the module's operator key is compromised, does the guard stop the attacker from moving 5,000 ETH out through execTransactionFromModule? Answer yes or no, then explain in one sentence.

**Answer:** No. In v1.4.1, execTransactionFromModule only checks that the caller is an enabled module, then executes without any guard call. Even in v1.5.0 (3 Jul 2025), module calls go through a separate module guard set with setModuleGuard, not the transaction guard.

**Why a model gets it wrong:** Models treat the guard as a policy hook on everything the Safe executes. Models that know v1.5.0 added module guards tend to assume it is the same guard.

**Backing:** No named loss found. Safe's own code warns: "A malicious module can completely takeover a Safe." Weak incident backing. An open variant asks the same question about v1.5.0 with only setGuard configured; the answer is still no.

**Spec source:**
- v1.4.1: https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/base/ModuleManager.sol (`execTransactionFromModule` calls no guard)
- v1.5.0: https://github.com/safe-global/safe-smart-account/blob/v1.5.0/contracts/base/ModuleManager.sol (`getModuleGuard()`, `checkModuleTransaction`)
- https://github.com/safe-global/safe-smart-account/blob/main/CHANGELOG.md

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** medium

### accounts-safe-delegatecall-slot0
**Instruction:**
You are checking a Safe transaction before signing. It has to = an unverified contract, value = 0, data = transfer(address,uint256) with a fresh address and amount 0, and operation = 1. The proposer calls it a harmless zero-value token transfer. If that contract's transfer function writes its address argument into storage slot 0, what happens to the Safe? Answer in one sentence.

**Answer:** It replaces the Safe's singleton (implementation) address. Operation 1 is a DELEGATECALL that runs the code against the Safe's own storage, and SafeProxy loads its singleton from slot 0, so every later call runs the attacker's code with full control of the funds.

**Why a model gets it wrong:** Models may assume Safe proxies use the EIP-1967 slot, or read the call as a token transfer. This is likely known, because Bybit was so widely covered.

**Backing:** Bybit, 21 Feb 2025, about $1.46B. Injected Safe{Wallet} JavaScript got three signers to approve an operation=1 call to a contract whose `transfer` wrote slot 0. https://www.nccgroup.com/research/in-depth-technical-analysis-of-the-bybit-hack/

**Spec source:** https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/proxies/SafeProxy.sol ("Singleton always needs to be first declared variable" and `sload(0)`)

**Grading:** judge: passes if the reply says the Safe's implementation (singleton or masterCopy) gets replaced, so the attacker controls the Safe; fails if it says nothing happens or that it is a token transfer.

**Your confidence a frontier model fails cold:** low

## Rejected on the way
- ERC-6900 `skipRuntimeValidation` ("can be called by anyone"): the flag's name gives the answer away, and ERC-6900 is a niche Draft.
- EntryPoint v0.8 folds the 7702 delegate into userOpHash when initCode is 0x7702 (verified in Eip7702Support.sol): narrow, with little security consequence, and close to the existing smart-accounts-userop-hash-v08 quiz.
- Replaying a userOp across chains: userOpHash includes chainId and the EntryPoint address, and every model knows it.
- ERC-7562 bans TIMESTAMP in validation: likely known; it is mentioned in the validUntil candidate's reasoning instead.
- ERC-7579 onUninstall reverting to block removal: the spec says the account MUST revert, but major accounts reportedly ignore the revert (I did not verify this), so the answer depends on the library.
- Trust in signature aggregators: no fixed-answer fact with a real incident found.
- Safe session keys and the allowance module: no crisp spec fact with an incident found within budget.
- A 7702 delegate without receive(), so ETH payouts revert: derivable by reasoning, and no incident.
- 7702 delegation chains and precompile targets: EVM trivia.
- SELFDESTRUCT inside a delegate (EIP-6780 only moves ETH): trivia, no incident.
- A leaked key stays all-powerful after delegation (CrimeEnjoyor sweepers): likely known.
- Phishing through wallet_sendCalls on accounts upgraded with 7702 ($146K on 24 May 2025, $1.54M on 24 Aug 2025): a wallet UX question whose answer depends on the wallet.
- EXTCODESIZE returning 23 and isContract checks: overlaps the permit2-7702 quiz that survived; covered by the flash-loan candidate.
- Removal of Safe v1.5.0's legacy ERC-1271 function: changelog trivia.
- Relayers griefed when a sponsored authorization is invalidated by a nonce bump: the EIP spells it out, and it is an operations concern rather than an audit question.

---

Pectra facts were checked against eips.ethereum.org (EIP-7702, ERC-7739, ERC-7579, ERC-7562, ERC-6900); EntryPoint and Safe behaviour against their tagged GitHub source.
