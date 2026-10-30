# Candidate security quizzes: signatures, approvals, wallet and frontend side

Wallet or frontend side (8): signatures-permit2-lockdown-leaves-signature, signatures-dai-permit-expiry-zero, signatures-safe-domain-hash-fields, signatures-safe-errored-signature-still-live, signatures-poisoning-real-usdc-event, signatures-5792-atomic-not-one-tx, signatures-7702-chainid-zero, signatures-safe-personal-sign-v.
Contract side (8): the rest.
Answer balance: 9 yes, 7 no.

### signatures-permit2-smart-account-replay
**Instruction:**
You are reviewing a smart account before launch. Its isValidSignature returns the ERC-1271 magic value whenever ecrecover(hash, signature) equals the account's owner, and it does nothing else to the hash. One EOA owns two of these accounts, A and B. Both have approved USDC to Uniswap's Permit2 and have no allowances inside Permit2 yet. The owner signs a Permit2 PermitSingle for account A. Can a relayer submit that same signature to Permit2's permit with owner set to account B and create an allowance on B? Answer yes or no, then explain in one sentence.

**Answer:** Yes. PermitSingle(PermitDetails details, address spender, uint256 sigDeadline) has no owner field and the domain is Permit2's, so the digest is the same for A and B; B's nonce for that token and spender is also 0, and B's isValidSignature checks only the recovered key.

**Why a model gets it wrong:** Models assume an EIP-712 permit always binds the owner, as EIP-2612's Permit(owner, spender, value, nonce, deadline) does, or that separate per-account nonces stop replay. They forget that Permit2 binds the owner only through signature verification.

**Backing:** Alchemy disclosure, found Oct 27 2023 (curiousapple reported it a month earlier). The ERC-1271 replay affected LightAccount, OKX SmartAccount and other accounts; Permit2 and CoW Swap were the named at-risk apps; no funds lost. https://www.alchemy.com/blog/erc-1271-signature-replay-vulnerability . It led to ERC-7739, whose motivation names Permit2: https://eips.ethereum.org/EIPS/eip-7739

**Spec source:** PermitHash.sol typehashes, no owner in any of them: https://github.com/Uniswap/permit2/blob/main/src/libraries/PermitHash.sol ; AllowanceTransfer.permit runs `signature.verify(_hashTypedData(permitSingle.hash()), owner)`: https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** medium

### signatures-safe-1271-no-cross-safe-replay
**Instruction:**
Two Safe v1.4.1 accounts, A and B, each have the same single owner, threshold 1, and the standard CompatibilityFallbackHandler. Both have approved USDC to Uniswap's Permit2. The owner produces a signature that Safe A's isValidSignature accepts for a Permit2 PermitSingle digest. Can a relayer submit that same signature to Permit2's permit with owner set to Safe B and create an allowance on B? Answer yes or no, then explain in one sentence.

**Answer:** No. The handler's isValidSignature(bytes32, bytes) checks owner signatures over getMessageHashForSafe(safe, abi.encode(hash)), a SafeMessage hashed under that Safe's own EIP-712 domain (chainId, verifyingContract = the Safe), so a signature valid for A fails on B.

**Why a model gets it wrong:** After the 2023 ERC-1271 replay story, models stretch "same owner key, replayable across smart accounts" to Safe. They don't know Safe already wraps every ERC-1271 hash in a SafeMessage bound to that Safe. This pairs with the candidate above; keep at most one.

**Backing:** Same Alchemy disclosure (Oct 2023), https://www.alchemy.com/blog/erc-1271-signature-replay-vulnerability . Safe's design is the counterexample. I did not confirm whether Alchemy named Safe as unaffected.

**Spec source:** https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/handler/CompatibilityFallbackHandler.sol (getMessageHashForSafe uses `safe.domainSeparator()`; the bytes32 overload re-enters with `abi.encode(_dataHash)`)

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** medium

### signatures-oz-ecdsa-signature-as-key
**Instruction:**
You are reviewing a vault's withdrawal-voucher flow before launch. An offchain service signs vouchers with one EOA key, `signer`.

```solidity
using ECDSA for bytes32; // OpenZeppelin Contracts 5.x
mapping(bytes32 => bool) public used;

function claim(uint256 amount, bytes calldata sig) external {
    bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(CLAIM_TYPEHASH, msg.sender, amount)));
    require(digest.recover(sig) == signer, "bad sig");
    require(!used[keccak256(sig)], "used");
    used[keccak256(sig)] = true;
    token.transfer(msg.sender, amount);
}
```

Can a user holding one valid voucher claim it twice by changing the signature bytes? Answer yes or no, then explain in one sentence.

**Answer:** No. OpenZeppelin 5.x's bytes overload of recover accepts only 65-byte signatures (so the EIP-2098 short form is rejected) and rejects s above n/2 (so the (r, n−s, v') twin is rejected), which leaves one accepted encoding per signature.

**Why a model gets it wrong:** The textbook reflex says keying on signature bytes is always malleable (SWC-117), so models answer yes. They don't recall that OpenZeppelin has enforced low-s for years and dropped compact signatures from the bytes overload in 4.7.3. The same code with Solady's ECDSA would answer yes; see Rejected.

**Backing:** OpenZeppelin advisory GHSA-4h98-2769-gh6h / CVE-2022-35961 (Aug 18 2022). ECDSA.recover in versions 4.1.0 to 4.7.2 accepted both 65- and 64-byte forms, which bypassed exactly this "mark signature as used" pattern; fixed in 4.7.3; no exploit known. https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-4h98-2769-gh6h

**Spec source:** https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol ("This function only supports 65-byte signatures. ERC-2098 short signatures are rejected"; `s > 0x7FFF…20A0` gives InvalidSignatureS)

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** medium

### signatures-safe-legacy-domain-cross-chain
**Instruction:**
A DAO runs a Safe at the same address on Ethereum and on another EVM chain. Both copies were deployed from the same factory with the same setup, both use the Safe v1.1.1 singleton, and both have the same owners, threshold and current nonce. The signers collect signatures on Ethereum for an execTransaction that calls swapOwner to replace one signer, and it executes there. Can anyone submit those same signatures to the Safe on the other chain and perform the same owner swap? Answer yes or no, then explain in one sentence.

**Answer:** Yes. Before v1.3.0, Safe's domain separator was keccak256(abi.encode(keccak256("EIP712Domain(address verifyingContract)"), this)) with no chainId, so the safeTxHash is the same on both chains; chainId entered the domain in v1.3.0.

**Why a model gets it wrong:** Models assume every EIP-712 domain carries chainId, as EIP-712 recommends, so "Safe uses EIP-712" leads them to "signatures are chain-bound".

**Backing:** I found no named loss from replaying Safe signatures. Related cases: Wintermute/Optimism, June 2022, 20M OP, where a Safe address existed on a second chain under someone else's control after a replayed factory deployment (https://slowmist.medium.com/slowmist-key-to-the-theft-of-20-million-op-tokens-transaction-replay-490baaf45f26), and the Code4rena Brahma (Oct 2023) finding "Signed data may be usable cross-chain" on Safe-based guards (https://vulners.com/code423n4/CODE423N4:2023-10-BRAHMA-FINDINGS-ISSUES-335). The backing is weak; the owner should decide.

**Spec source:** https://github.com/safe-global/safe-smart-account/blob/v1.1.1/contracts/GnosisSafe.sol and v1.2.0 (verifyingContract only); https://github.com/safe-global/safe-smart-account/blob/v1.3.0/contracts/GnosisSafe.sol (adds chainId)

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** high

### signatures-oz-eip712-fork-recompute
**Instruction:**
You are reviewing a token that inherits OpenZeppelin Contracts 5.x ERC20Permit. Its EIP712 base computes the domain separator in the constructor and stores it in an immutable. The chain then hard-forks: the forked chain gets a new chain ID and keeps the token's full state. A holder signs a permit on the original chain and it is submitted there. Can someone submit the same signature on the forked chain and set the same allowance? Answer yes or no, then explain in one sentence.

**Answer:** No. _domainSeparatorV4 returns the cached value only when address(this) == _cachedThis and block.chainid == _cachedChainId; otherwise it rebuilds the separator with the current block.chainid, so the fork's digest differs.

**Why a model gets it wrong:** The EIP-2612 warning ("a cached domain separator breaks on forks") and the word immutable push models to yes. They don't recall that OpenZeppelin (and Solady) cache the chain ID too and recompute when it changes.

**Backing:** Omni Bridge on EthereumPoW, Sept 16 to 18 2022. The bridge checked a chain ID read from storage, so the attacker replayed a Gnosis Chain bridge message and received 200 ETHW per replay. https://blocksec.com/blog/reveal-the-message-replay-attacks-on-ethereum-po-w . Code4rena Shell Protocol (Nov 2023) flagged an immutable DOMAIN_SEPARATOR without this check: https://vulners.com/code423n4/CODE423N4:2023-11-SHELLPROTOCOL-FINDINGS-ISSUES-196

**Spec source:** https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** medium

### signatures-permit2-unordered-nonce
**Instruction:**
A user signs two Uniswap Permit2 PermitTransferFrom messages for the same token and the same spender, one with nonce 5 and one with nonce 7, both with deadlines next week. The spender submits the nonce 7 permit through permitTransferFrom and it succeeds. Can the spender still submit the nonce 5 permit afterwards? Answer yes or no, then explain in one sentence.

**Answer:** Yes. SignatureTransfer uses unordered nonces stored as bits in nonceBitmap[owner][wordPos], so using 7 flips only bit 7; nonce 5 stays live until it is used or cancelled with invalidateUnorderedNonces.

**Why a model gets it wrong:** Models carry over sequential-nonce semantics from EIP-2612 and from Permit2's own AllowanceTransfer, where a higher nonce means the lower ones are spent.

**Backing:** Permit2 signature phishing. In Oct 2024 a PEPE holder lost about $1.4M after one Permit2 signature (Scam Sniffer, reported via press: https://journalducoin.com/defi/holder-pepe-perd-1-4-million-dollars-attaque-phishing-sophistiquee/). SlowMist counts about $690k from about 300 victims in an earlier Permit2 wave: https://slowmist.medium.com/examining-permit-signatures-is-phishing-of-tokens-possible-via-off-chain-signatures-bfb5723a5e9 . The link is indirect: stale signed permits stay live.

**Spec source:** https://github.com/Uniswap/permit2/blob/main/src/SignatureTransfer.sol (_useUnorderedNonce, invalidateUnorderedNonces)

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** medium

### signatures-weth-phantom-permit
**Instruction:**
You are reviewing a router on Ethereum mainnet that many users have approved for unlimited WETH (the canonical WETH9 contract). Its depositWithPermit(token, owner, value, deadline, v, r, s, recipient) calls IERC20Permit(token).permit(owner, address(this), value, deadline, v, r, s), then token.transferFrom(owner, address(this), value), then credits recipient. An attacker calls it with token = WETH, a victim as owner, random bytes for v, r and s, and themselves as recipient. Can the attacker take the victim's WETH this way? Answer yes or no, then explain in one sentence.

**Answer:** Yes. WETH9 has no permit function; its fallback runs deposit() with msg.value 0 and does not revert, so the "permit" silently succeeds and transferFrom then uses the victim's standing approval.

**Why a model gets it wrong:** Likely known, since Dedaub's "phantom functions" write-up is widely taught. A model that misses it assumes a call to a missing function reverts.

**Backing:** Multichain (AnySwap) phantom-permit disclosure, Jan 10 2022; Dedaub estimated $431M of WETH at risk on Ethereum: https://dedaub.com/blog/phantom-functions-and-the-billion-dollar-no-op/ . I did not verify the amount actually stolen before the patch.

**Spec source:** WETH9 at 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 (fallback calls deposit). Not fetched this session; the mechanism is confirmed by the Coinspect reproduction: https://github.com/coinspect/learn-evm-attacks/tree/master/test/Bad_Data_Validation/Multichain_Permit

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** low

### signatures-permit2-signaturetransfer-frontrun
**Instruction:**
A user calls a vault's depositWithPermit2 and passes a Uniswap Permit2 PermitTransferFrom signature. The vault calls Permit2's permitTransferFrom to pull the tokens to itself. A searcher copies the signature and permit data from the public mempool, then calls permitTransferFrom on Permit2 directly, earlier in the block, with transferDetails.to set to the searcher's own address. Does the searcher's call move the user's tokens? Answer yes or no, then explain in one sentence.

**Answer:** No. When hashing PermitTransferFrom, SignatureTransfer puts msg.sender in the spender field, so the searcher's call produces a different digest and fails; only the vault can use the signature.

**Why a model gets it wrong:** Models stretch the EIP-2612 story (anyone can submit a permit) and Permit2 AllowanceTransfer's relayer-submittable permit to SignatureTransfer, and treat the signature as a bearer instrument.

**Backing:** 2024 permit-frontrunning reports, Immunefi Puffer #28702 (Feb 2024) and ZeroLend #29244 (Mar 2024): https://reports.immunefi.com/puffer-finance/28702-sc-insight-malicious-users-can-frontrun-permits-to-dos-swaps . Those cover EIP-2612 griefing; with SignatureTransfer the frontrunner cannot even use up the nonce.

**Spec source:** https://github.com/Uniswap/permit2/blob/main/src/libraries/PermitHash.sol (PermitTransferFrom typehash has `address spender`, filled with msg.sender)

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** low

### signatures-permit2-lockdown-leaves-signature
**Instruction:**
A user on Ethereum mainnet signed a Uniswap Permit2 PermitBatchTransferFrom on a phishing site. It names the attacker's contract as spender for the user's USDC and WETH, with a deadline next month. The attacker has not submitted it yet. The user's wallet offers a one-click fix that calls Permit2's lockdown for each (token, attacker) pair, and that transaction confirms. Can the attacker still use the signature to take the tokens? Answer yes or no, then explain in one sentence.

**Answer:** Yes. lockdown only sets AllowanceTransfer's allowance[owner][token][spender].amount to 0, and SignatureTransfer never reads that mapping. The permit stays valid until its nonce is invalidated with invalidateUnorderedNonces or the user revokes each token's ERC-20 approval to Permit2 itself.

**Why a model gets it wrong:** Models treat Permit2 as one allowance system and assume that revoking the spender inside Permit2 kills every Permit2 authorization; the AllowanceTransfer/SignatureTransfer split is less well known.

**Backing:** Oct 2024 PEPE holder, about $1.4M from one Permit2 signature (Scam Sniffer, via press, above). Scam Sniffer's Permit2 revocation tool: https://drops.scamsniffer.io/introducing-uniswap-permit2-authorization-management/

**Spec source:** https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol (lockdown) and https://github.com/Uniswap/permit2/blob/main/src/SignatureTransfer.sol (its only storage is nonceBitmap)

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** high

### signatures-dai-permit-expiry-zero
**Instruction:**
Your wallet's signature-review screen is deciding whether to warn. A site asks a user on Ethereum mainnet to sign DAI's permit, Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed), with allowed = true and expiry = 0, and then never submits it. Could the spender still use this signature a year from now? Answer yes or no, then explain in one sentence.

**Answer:** Yes. DAI checks `require(expiry == 0 || now <= expiry)`, so expiry 0 never expires, and allowed = true sets the allowance to uint(-1). The signature stays live until that nonce is used.

**Why a model gets it wrong:** Models read DAI's permit as EIP-2612, where the deadline is a timestamp and 0 is long past. They forget DAI's permit predates EIP-2612 and has its own rules.

**Backing:** Permit phishing in general: in June 2024 a MakerDAO delegate lost about $11M (aEthMKR and Pendle USDe) by signing permit signatures, https://crypto.news/makerdao-delegate-loses-11m-in-major-phishing-scam . I did not verify a loss tied specifically to a DAI permit with expiry 0.

**Spec source:** https://github.com/makerdao/dss/blob/master/src/dai.sol (permit)

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** high

### signatures-safe-domain-hash-fields
**Instruction:**
After the Bybit theft, your multisig's signers recompute each Safe transaction hash on a separate machine and compare it with what their hardware wallet shows. Your script builds the EIP712Domain for a Safe on the v1.4.1 singleton from name "Safe", version "1.4.1", chainId and verifyingContract. Will it reproduce the safeTxHash the Safe contract checks? Answer yes or no, then explain in one sentence.

**Answer:** No. Safe's domain type is EIP712Domain(uint256 chainId,address verifyingContract), with no name or version, so the extra fields change the domain hash.

**Why a model gets it wrong:** Models assume every EIP-712 domain has name and version, as OpenZeppelin EIP712 and EIP-2612 tokens do.

**Backing:** Bybit, Feb 21 2025, about $1.46B. Injected JavaScript in the Safe{Wallet} UI changed operation to delegatecall while Ledgers showed only hashes: https://www.nccgroup.com/research/in-depth-technical-analysis-of-the-bybit-hack/ . Radiant, Oct 16 2024, about $50M, blind-signed Safe transactions: https://medium.com/@RadiantCapital/radiant-post-mortem-fecd6cd38081 . SEAL's guidance: "Message Hash on tools must match hardware wallet display": https://frameworks.securityalliance.org/wallet-security/signing-and-verification/secure-multisig-safe-verification

**Spec source:** https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/Safe.sol (DOMAIN_SEPARATOR_TYPEHASH 0x47e795…9218, domainSeparator())

**Grading:** judge: the answer is no, and the reason given is that the Safe domain has no name or version field (only chainId and verifyingContract)

**Your confidence a frontier model fails cold:** medium

### signatures-safe-errored-signature-still-live
**Instruction:**
A Safe signer approves a transaction on their hardware wallet. The Safe web app then shows an error and asks them to sign again, and they do. Suspecting malware swapped the first transaction, the signer deletes the queued transaction in the Safe web app. Nothing has executed, and the Safe's nonce has not moved. Could an attacker who captured the first signature still use it? Answer yes or no, then explain in one sentence.

**Answer:** Yes. A Safe owner signature over a safeTxHash has no expiry and stays valid until that Safe nonce is used (or owners or threshold change); a UI error or deleting the item from the offchain queue changes nothing onchain, and only executing another transaction at that nonce kills it.

**Why a model gets it wrong:** Probably answerable by reasoning. A model fails only if it assumes that deleting a transaction from the queue cancels it.

**Backing:** Radiant Capital, Oct 16 2024, about $50M. Malware showed the real transaction in the UI, sent a malicious one to the hardware wallets, showed an error, and had signers sign again, which produced valid malicious signatures: https://medium.com/@RadiantCapital/radiant-post-mortem-fecd6cd38081 (quoted via search; that transferOwnership was the payload comes from secondary sources)

**Spec source:** https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/Safe.sol (checkNSignatures has no expiry; safeTxHash includes nonce). I did not verify Safe's help-centre wording on queue deletion.

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** low

### signatures-poisoning-real-usdc-event
**Instruction:**
Your wallet's activity feed builds a user's "Sent" list from Transfer events on the real USDC contract on Ethereum mainnet where from equals the user's address. A user reports a "Sent 0 USDC" entry to an address that looks like their exchange deposit address, and says they never signed anything or approved anyone. Could a stranger have produced that event without the user's key or any allowance? Answer yes or no, then explain in one sentence.

**Answer:** Yes. USDC's transferFrom only requires value <= allowance, so anyone can call transferFrom(user, lookalike, 0) with zero allowance, and it emits Transfer(user, lookalike, 0).

**Why a model gets it wrong:** Models know address poisoning through dust and fake tokens, but assume a Transfer event with from = user on the genuine token contract proves that the user or an approved spender acted.

**Backing:** May 2025: a trader lost about $2.6M in two address-poisoning scams that used zero-value transfers, https://cointelegraph.com/explained/a-crypto-scam-that-doesnt-need-private-keys-how-does-zero-value-transfer-work ; a USDT poisoning loss of about $50M (date disputed, Dec 2024 or 2025), https://cointelegraph.com/news/address-poisoning-copy-paste-mistake-50m-usdt-loss

**Spec source:** https://github.com/circlefin/stablecoin-evm/blob/master/contracts/v1/FiatTokenV1.sol (transferFrom: `value <= allowed[from][msg.sender]`, then `_transfer` emits Transfer); OpenZeppelin ERC20 `_spendAllowance` behaves the same

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** medium

### signatures-5792-atomic-not-one-tx
**Instruction:**
Your dapp sends an EIP-5792 wallet_sendCalls request with atomicRequired: true, containing approve(vault, amount) and vault.deposit(amount). Your backend then credits the deposit by fetching one transaction receipt and reading both the Approval and the Deposit events from it. Does EIP-5792 let the dapp assume both calls were sent in a single transaction? Answer yes or no, then explain in one sentence.

**Answer:** No. atomicRequired: true guarantees all-or-nothing and contiguous execution, but the spec says "App developers MUST NOT assume that all calls will be sent in a single transaction" regardless of atomic, so the backend must read every receipt wallet_getCallsStatus returns.

**Why a model gets it wrong:** Models treat "atomic batch" as "one transaction", which is what 7702 and 4337 accounts usually deliver.

**Backing:** No named incident; this one rests on the spec alone. Its main value is that the two existing 5792 quizzes survived.

**Spec source:** https://eips.ethereum.org/EIPS/eip-5792 (Security Considerations)

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** medium

### signatures-7702-chainid-zero
**Instruction:**
You are reviewing a wallet's EIP-7702 upgrade flow before launch. To spare users from signing once per network, it has them sign a single authorization with chain_id = 0 for the wallet's delegate contract at address D, signed while connected to Ethereum mainnet. Can that same signed authorization be applied on other chains? Answer yes or no, then explain in one sentence.

**Answer:** Yes. EIP-7702 accepts an authorization whose chain_id is 0 or the current chain's ID, so it can be applied on any 7702 chain where the account's nonce matches, delegating to whatever code sits at D on that chain.

**Why a model gets it wrong:** Likely known, since chain_id 0 appears in the EIP's rationale. A model that misses it assumes every signature is chain-bound, as in EIP-155.

**Backing:** 2025 EIP-7702 phishing: Wintermute (June 2025) reported that over 80% of delegations went to sweeper scripts, https://www.theblock.co/post/356481/wintermute-warns-pectra-upgrade-leaves-ethereum-users-at-risk-of-automated-attacks ; SEAL: "A signature authorizing a delegation with chain ID 0 can be replayed on other EVM chains", https://frameworks.securityalliance.org/wallet-security/signing-and-verification/verifying-7702 . I found no loss tied specifically to chain_id 0.

**Spec source:** https://eips.ethereum.org/EIPS/eip-7702 ("Verify the chain ID is 0 or the ID of the current chain")

**Grading:** pattern: starts with yes

**Your confidence a frontier model fails cold:** low

### signatures-safe-personal-sign-v
**Instruction:**
A Safe v1.4.1 owner uses a hardware wallet that cannot sign EIP-712 typed data. Your signing tool has them personal_sign the 32-byte safeTxHash instead and passes the 65-byte result to execTransaction unchanged, with v = 27 or 28. Will the Safe accept that signature? Answer yes or no, then explain in one sentence.

**Answer:** No. With v ≤ 30, Safe runs a plain ecrecover over the safeTxHash, but personal_sign signed keccak256("\x19Ethereum Signed Message:\n32" || safeTxHash); the tool must add 4 to v (31 or 32) to select Safe's eth_sign branch.

**Why a model gets it wrong:** Models know Safe supports eth_sign-style signatures but not that the branch is selected by v + 4, or they assume Safe detects the prefix on its own.

**Backing:** Signer tooling around blind signing on hardware wallets (Radiant Oct 2024, Bybit Feb 2025, links above). I found no incident caused by this encoding.

**Spec source:** https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/Safe.sol (checkNSignatures `v > 30` branch: `ecrecover(keccak256("\x19Ethereum Signed Message:\n32", dataHash), v - 4, r, s)`)

**Grading:** pattern: starts with no

**Your confidence a frontier model fails cold:** medium

## Rejected on the way
- ecrecover returning address(0) with an unset signer: textbook (SWC-117/122).
- The Solady ECDSA version of the signature-as-key code: verified that Solady accepts high-s and 64-byte forms, but the answer is yes, and the textbook reflex also gives yes.
- OpenZeppelin EIP712 in EIP-1167 clones (no replay across clones, thanks to the _cachedThis check): can be worked out by reasoning, and I found no named incident.
- An immutable DOMAIN_SEPARATOR baked into a clone implementation (replay across clones): the code makes it obvious, and I found no incident.
- EIP-2612 permit frontrun griefing inside a multicall: every model knows the try/catch fix.
- approve(spender, 0) does not cancel an unsubmitted EIP-2612 permit: overlaps the Permit2 lockdown candidate and can be worked out by reasoning.
- Permit2 sigDeadline vs expiration, and the missing version field in Permit2's domain: overlap existing Permit2 quizzes or are not security.
- Ledger Connect Kit, Dec 14 2023 (versions 1.1.5 to 1.1.7, loader pulled latest from a CDN at runtime): once the setup is stated, reasoning gives the answer; without it, it's news recall.
- Curve DNS hijack, Aug 9 2022, about $570k (real origin and a valid TLS certificate under hijacked DNS): every model gets it by reasoning.
- Bybit "operation = 1 delegatecall can replace the singleton": textbook since Feb 2025.
- Seaport bulk orders (docs say the payload is "typed, human-readable EIP 712 data", unlike a bare Merkle root): no incident verified; borderline wallet trivia.
- Seaport incrementCounter cancels all orders: likely known incident-response trivia.
- Blur bulk-listing Root signature phishing: not verified within budget.
- Safe v1.4.1 calls the legacy isValidSignature(bytes,bytes) on contract owners: verified in code, but no incident, and the risk is liveness, not theft.
- Safe v=1 branch accepts msg.sender == owner with no signature: verified, but CTF-flavoured, with no incident.
- What a hardware wallet can show for EIP-712: depends on vendor and firmware, so there is no fixed answer.
- personal_sign vs typed-data prefixes (0x19 0x45 vs 0x19 0x01): textbook.
- MetaMask's domain.chainId check: specific to one wallet.
- EIP-5792 atomicRequired: false on an atomic-capable wallet: the answer follows from the flag's name, and it overlaps the existing 5792 quizzes.
- Approval drains through arbitrary calls to routers (LI.FI Jul 2024, Socket Jan 2024, Seneca Feb 2024): the lesson is textbook.

---

Unverified items to check before keeping any of these:
- **WETH9 fallback:** the code itself wasn't fetched; the mechanism comes from the Dedaub and Coinspect search results.
- **Secondary sources only:** the Multichain stolen amount, the Oct 2024 $1.4M Permit2 PEPE case, and the transferOwnership payload in Radiant.
- **Not confirmed:** the May 2024 1,155 WBTC poisoning case. Left out.
- **No named loss:** the Safe cross-chain replay and the EIP-5792 candidates.
