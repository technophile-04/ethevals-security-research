### accounts-7702-eoa-only-flashloan
Verdict: CORRECT
Note: Yes; delegated code can call stake from the transaction sender's address, including during a flash-loan callback ([EIP-7702](https://eips.ethereum.org/EIPS/eip-7702#backwards-compatibility)).

### accounts-7702-delegation-survives-revert
Verdict: CORRECT
Note: Yes; execution failure leaves processed delegation indicators intact ([EIP-7702, Behavior](https://eips.ethereum.org/EIPS/eip-7702#behavior)).

### accounts-7702-init-frontrun
Verdict: CORRECT
Note: No; the authorization signs the delegate and nonce, leaving initialization calldata open to substitution ([EIP-7702](https://eips.ethereum.org/EIPS/eip-7702#front-running-initialization)).

### accounts-7702-chainid-zero-revocation
Verdict: CORRECT
Note: Yes; chain ID zero permits replay on Base at nonce 7, which mainnet revocation does not change ([EIP-7702](https://eips.ethereum.org/EIPS/eip-7702#behavior)).

### accounts-7702-self-sponsored-nonce
Verdict: CORRECT
Note: 42; the transaction increments its sender's nonce before processing authorizations ([EIP-7702](https://eips.ethereum.org/EIPS/eip-7702#behavior)).

### accounts-7702-redelegation-initializable
Verdict: AMBIGUOUS
Note: No holds for the default slot, but yes is defensible because OpenZeppelin 5.4 permits overriding `_initializableStorageSlot()` to select fresh storage ([lines 219–235](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/contracts/proxy/utils/Initializable.sol#L219)). This depends on library behavior despite the brief's library-independent requirement; specify the default, unmodified slot.

### accounts-7702-delegate-unguarded-call
Verdict: CORRECT
Note: Yes; a call to delegated code executes in the admin account's context, so an outbound CALL identifies the admin as sender ([EIP-7702](https://eips.ethereum.org/EIPS/eip-7702#delegation-indicator)).

### accounts-4337-validuntil-zero
Verdict: CORRECT
Note: Yes, provided the key passes the remaining validation; zero means no expiry ([v0.7 Helpers.sol](https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/core/Helpers.sol#L45)). Deleting the entry only revokes it if the validator rejects absent keys, so qualify that suggested fix.

### accounts-4337-v07-postop-charge
Verdict: CORRECT
Note: The paymaster pays; v0.7 rolls back execution and skips a second paymaster postOp call ([EntryPoint.sol](https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/core/EntryPoint.sol#L704)). The stated answer starts with "The paymaster", which fails the literal grading prefix "paymaster".

### accounts-4337-unused-gas-penalty
Verdict: CORRECT
Note: No; v0.7 adds 10% of unused execution and postOp gas to the charge ([EntryPoint.sol](https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/core/EntryPoint.sol#L718)). The 485,000 figure is approximate because the formula also includes postOp gas and EntryPoint execution overhead.

### accounts-4337-unstaked-paymaster-context
Verdict: CORRECT
Note: No; EREP-050 bars unstaked paymasters from returning context in the shared mempool ([ERC-7562](https://eips.ethereum.org/EIPS/eip-7562#entity-specific-rules)).

### accounts-1271-permit2-cross-account-replay
Verdict: CORRECT
Note: Yes; PermitSingle omits the owner, and each account accepts the same digest with the same initial nonce ([PermitHash.sol](https://github.com/Uniswap/permit2/blob/main/src/libraries/PermitHash.sol#L11), [ERC-7739](https://eips.ethereum.org/EIPS/eip-7739#motivation)). Creating this Permit2 allowance does not itself require a prior USDC approval to Permit2.

### accounts-7739-typeddatasign-domain
Verdict: CORRECT
Note: The dapp's domain remains outside TypedDataSign; the account's domain fields sit inside its struct ([ERC-7739](https://eips.ethereum.org/EIPS/eip-7739#typeddatasign-final-hash)).

### accounts-7579-fallback-sender
Verdict: CORRECT
Note: Yes; CALL makes the account the handler's msg.sender, and the installed executor can call back into that account ([ERC-7579](https://eips.ethereum.org/EIPS/eip-7579#fallback-handlers)). The appended ERC-2771 sender is the stranger the handler fails to authorize.

### accounts-safe-guard-module-path
Verdict: CORRECT
Note: No; v1.4.1 checks module membership and executes without consulting the transaction guard ([ModuleManager.sol](https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/base/ModuleManager.sol#L81)). Version 1.5.0 uses a separate module guard, as the answer states.

### accounts-safe-delegatecall-slot0
Verdict: AMBIGUOUS
Note: Replacing the singleton is correct, but a careful auditor can answer "the Safe becomes unusable" if the fresh address has no code ([SafeProxy.sol](https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/proxies/SafeProxy.sol#L35)). The instruction never gives that address attacker-controlled code, so the required claim of attacker control exceeds the facts.

### signatures-permit2-smart-account-replay
Verdict: CORRECT
Note: Yes; PermitSingle omits the account address, and Permit2 passes the same digest to B's permissive signature check ([PermitHash.sol](https://github.com/Uniswap/permit2/blob/main/src/libraries/PermitHash.sol#L11), [AllowanceTransfer.sol](https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol#L33)).

### signatures-safe-1271-no-cross-safe-replay
Verdict: AMBIGUOUS
Note: No holds for an EOA owner's ECDSA signature, but yes is defensible for a shared contract owner that accepts the same signature for both wrapped messages ([Safe.sol, contract-signature branch](https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/Safe.sol#L286)). Specify an EOA owner and an ECDSA signature; the instruction currently allows Safe's other signature forms.

### signatures-oz-ecdsa-signature-as-key
Verdict: CORRECT
Note: No; the bytes overload requires 65 bytes and rejects high-s signatures, closing both stated encoding attacks ([ECDSA.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol)). This answer depends on OpenZeppelin's overload behavior and conflicts with the brief's library-independent requirement.

### signatures-safe-legacy-domain-cross-chain
Verdict: CORRECT
Note: Yes; the v1.1.1 domain contains only the Safe address, so matching transaction fields and nonces yield the same digest ([GnosisSafe.sol](https://github.com/safe-global/safe-smart-account/blob/v1.1.1/contracts/GnosisSafe.sol#L89)). Version 1.3.0 adds the current chain ID to that domain.

### signatures-oz-eip712-fork-recompute
Verdict: CORRECT
Note: No; OpenZeppelin rebuilds the domain separator when the current chain ID differs from its cached value ([EIP712.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol#L92)). This depends on OpenZeppelin's cache implementation and conflicts with the brief's library-independent requirement.

### signatures-permit2-unordered-nonce
Verdict: CORRECT
Note: Yes; consuming nonce 7 changes its own bitmap bit and leaves nonce 5 available ([SignatureTransfer.sol](https://github.com/Uniswap/permit2/blob/main/src/SignatureTransfer.sol#L150)).

### signatures-weth-phantom-permit
Verdict: CORRECT
Note: Yes; WETH9's payable fallback accepts the unknown permit selector, and its transferFrom uses the victim's existing router approval ([canonical WETH9 source](https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol#L31)). The permit interface expects no return data, so the empty return does not cause ABI decoding to revert.

### signatures-permit2-signaturetransfer-frontrun
Verdict: CORRECT
Note: No; the digest includes msg.sender as spender, so calling Permit2 directly from the searcher's address changes the signed message ([PermitHash.sol](https://github.com/Uniswap/permit2/blob/main/src/libraries/PermitHash.sol#L59)).

### signatures-permit2-lockdown-leaves-signature
Verdict: CORRECT
Note: Yes, while the user's ERC-20 approvals remain; lockdown only clears AllowanceTransfer amounts ([AllowanceTransfer.sol](https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol#L97)). SignatureTransfer checks its separate nonce bitmap, and the signed deadline still applies ([SignatureTransfer.sol](https://github.com/Uniswap/permit2/blob/main/src/SignatureTransfer.sol)).

### signatures-dai-permit-expiry-zero
Verdict: CORRECT
Note: Yes; expiry zero bypasses DAI's time check, provided the signed nonce remains current ([dai.sol](https://github.com/makerdao/dss/blob/master/src/dai.sol#L141)).

### signatures-safe-domain-hash-fields
Verdict: CORRECT
Note: No; Safe v1.4.1 defines its domain with chainId and verifyingContract only, so including name and version changes the digest ([Safe.sol](https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/Safe.sol#L49)).

### signatures-safe-errored-signature-still-live
Verdict: CORRECT
Note: Yes; deleting an offchain queue entry cannot invalidate a signature over an unused Safe nonce ([Safe.sol](https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/Safe.sol#L383)). One captured signature still needs enough other valid signatures to meet the Safe's threshold; a threshold change alone does not necessarily invalidate it.

### signatures-poisoning-real-usdc-event
Verdict: CORRECT
Note: Yes; zero satisfies the allowance and balance checks, and the transfer emits its event ([FiatTokenV1.sol](https://github.com/circlefin/stablecoin-evm/blob/master/contracts/v1/FiatTokenV1.sol#L272)). Normal pause and blacklist restrictions still apply.

### signatures-5792-atomic-not-one-tx
Verdict: CORRECT
Note: No; the standard expressly forbids assuming one transaction regardless of atomicity, and permits multiple receipts for atomic execution ([EIP-5792](https://eips.ethereum.org/EIPS/eip-5792#security-considerations)).

### signatures-7702-chainid-zero
Verdict: CORRECT
Note: Yes; chain ID zero permits use on other EIP-7702 chains when the account nonce and other authorization checks match ([EIP-7702](https://eips.ethereum.org/EIPS/eip-7702#behavior)).

### signatures-safe-personal-sign-v
Verdict: CORRECT
Note: No; v = 27 or 28 selects raw-hash recovery, while v = 31 or 32 selects the Ethereum signed-message prefix ([Safe.sol](https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/Safe.sol#L322)). The answer's broader phrase "v ≤ 30" needs narrowing, since v = 0 and v = 1 select different branches.
