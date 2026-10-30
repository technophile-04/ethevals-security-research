# Upgrades, storage layout, deployment, and admin keys

Fourteen candidates. Confidence rates the chance of a frontier model failing cold, not source quality. No model trials have run. Two candidates receive a high rating. Research used 40 search, open, or find operations, counting failed requests.

### upgrades-selfdestruct-old-implementation
**Instruction:**
Can this attack still erase the implementation's code on Ethereum mainnet after Cancun? You are reviewing a legacy proxy deployment. Its implementation existed before the attack transaction and remains uninitialized. An attacker initializes that implementation directly, then makes it delegatecall a helper that executes SELFDESTRUCT. Assume every authorization check passes. Answer yes or no, then explain in one sentence.

**Answer:** No. EIP-6780 preserves code and storage when the executing account existed before the transaction.

**Why a model gets it wrong:** Models repeat the pre-Cancun UUPS bricking explanation without applying the changed SELFDESTRUCT rules.

**Backing:** Wormhole's February 24, 2022 disclosure exposed this implementation-destruction route; no funds were lost, and the researcher received $10 million. https://immunefi.com/blog/bug-fix-reviews/wormhole-uninitialized-proxy-bugfix-review/

**Spec source:** https://eips.ethereum.org/EIPS/eip-6780#specification

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### upgrades-handover-retained-role
**Instruction:**
Can the former developer still withdraw funds after this handover? You are reviewing a vault that independently inherits Ownable2Step and AccessControl. Governance has accepted ownership, and the developer has renounced DEFAULT_ADMIN_ROLE. The developer still holds WITHDRAWER_ROLE. The withdrawal function checks only that role, and no custom handover code revokes it. Answer yes or no, then explain in one sentence.

**Answer:** Yes. Ownership transfer and renouncing the role's admin do not revoke an existing WITHDRAWER_ROLE grant.

**Why a model gets it wrong:** A model can conflate authority to manage roles with existing role membership, although this is likely known.

**Backing:** Infini lost about $49.5 million on February 24, 2025 after a former developer retained withdrawal authority; the exact combination of OpenZeppelin bases here is illustrative. https://rekt.news/infini-rekt

**Spec source:** https://docs.openzeppelin.com/contracts/5.x/access-control#role-based-access-control

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** low

### upgrades-v5-proxyadmin-constructor
**Instruction:**
Can the Safe upgrade this new vault through its existing ProxyAdmin? You are reviewing a deployment script that uses unmodified OpenZeppelin Contracts 5.2.0. It calls `new TransparentUpgradeableProxy(implementation, address(existingProxyAdmin), initData)`. The Safe owns `existingProxyAdmin`, which exposes only the standard ProxyAdmin functions. Initialization succeeds and cannot change upgrade authority. Answer yes or no, then explain in one sentence.

**Answer:** No. The proxy creates another ProxyAdmin owned by existingProxyAdmin, whose standard interface cannot forward the required owner call.

**Why a model gets it wrong:** Models apply the 4.x constructor's admin parameter to 5.x, where that argument instead names the new ProxyAdmin's owner.

**Backing:** Guardian's Citrea Stablecoin Bridge audit, September 29, 2025, L-01, disclosed missing ProxyAdmin ownership configuration and explained this constructor change; no loss reported. The nested-ProxyAdmin example isolates the same changed parameter semantics. https://www.guardian.security/portfolio/citrea/stablecoin-bridge-2025-09-29/

**Spec source:** https://docs.openzeppelin.com/contracts/5.x/api/proxy#TransparentUpgradeableProxy-constructor-address-address-bytes-

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** high

### upgrades-v56-empty-initialization
**Instruction:**
Does this deployment succeed with empty initialization data? You are reviewing an Ethereum vault launch using unmodified OpenZeppelin Contracts 5.6.0. The script calls `new ERC1967Proxy(address(implementation), bytes(""))` and plans to initialize the proxy in its next transaction. The implementation has valid code, the constructor receives no ETH, and no contract overrides `_unsafeAllowUninitialized`. Answer yes or no, then explain in one sentence.

**Answer:** No. Version 5.6.0 rejects empty initialization data during construction unless the new opt-out hook allows it.

**Why a model gets it wrong:** Older versions allowed this deployment, so models can report an initialization race instead of the constructor's immediate revert.

**Backing:** USPD's preliminary post-mortem describes a September 16, 2025 proxy-initialization hijack, exploited on December 4, 2025. The candidate asks about a later library defense, not USPD's deployed library version. https://uspd.io/blog/cpimp-attack-postmortem

**Spec source:** OpenZeppelin 5.6.0 release, February 25, 2026, and pinned constructor code. https://docs.openzeppelin.com/contracts/5.x/changelog#v5.6.0; https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.6.0/contracts/proxy/ERC1967/ERC1967Proxy.sol

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** high

### upgrades-vault-owner-not-proxyadmin
**Instruction:**
Does this handover force upgrades through the timelock? You are reviewing an OpenZeppelin transparent proxy vault. Governance has accepted the vault's Ownable2Step ownership through a 48-hour timelock. The vault exposes no UUPS upgrade function. Its separate ProxyAdmin still belongs to the deployment EOA, which can call ProxyAdmin directly. Answer yes or no, then explain in one sentence.

**Answer:** No. ProxyAdmin ownership controls this upgrade path independently of the vault's owner and timelock.

**Why a model gets it wrong:** A model can treat the application owner as the sole authority, but this separation is likely known.

**Backing:** Moby's January 8, 2025 admin-key compromise enabled proxy upgrades and withdrawals of about $2.56 million before recoveries. Blockscope's investigation reconstructs those transactions; it does not claim Moby had the hypothetical timelock. https://research.blockscope.co/moby-trade-and-the-breached-private-key

**Spec source:** https://docs.openzeppelin.com/contracts/5.x/api/proxy#ProxyAdmin

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

### upgrades-constructor-initializer-version
**Instruction:**
Can a stranger call `initializeV2` directly on this implementation? You are reviewing a vault implementation that uses OpenZeppelin Contracts 4.9.6 Initializable. Its constructor is `constructor() initializer {}`. It also defines `function initializeV2() external reinitializer(2) { treasury = msg.sender; }`. No other modifier applies, and no call has followed deployment. Answer yes or no, then explain in one sentence.

**Answer:** Yes. The constructor consumes version 1, which leaves the version 2 reinitializer callable on the implementation.

**Why a model gets it wrong:** Models can treat a constructor marked initializer as equivalent to `_disableInitializers()`, although that equivalence ended with versioned reinitialization.

**Backing:** Dedaub's Archblock Stablecoins and GBPT Upgrade audit, January 24, 2024, L1, disclosed this exact obsolete constructor pattern. Its particular reinitializer used a fixed admin and did not establish direct theft. https://dedaub.com/audits/archblock/archblock-stablecoins-gbpt-upgrade-jan-24-2024

**Spec source:** https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.6/contracts/proxy/utils/Initializable.sol

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** medium

### upgrades-namespace-nested-struct-growth
**Instruction:**
Does this upgrade preserve existing shares? You are reviewing a vault whose entire state uses one ERC-7201 namespace with an unchanged root. V1 stores `struct State { Limits limits; mapping(address => uint256) shares; }`, where `Limits` contains one uint256. V2 appends another uint256 inside Limits and leaves State's member order unchanged. No migration copies storage. Answer yes or no, then explain in one sentence.

**Answer:** No. Growing the nested struct shifts the shares mapping's slot within the namespace, so lookups use different storage locations.

**Why a model gets it wrong:** Models can overextend the rule that namespaced storage permits base-contract changes and assume appending inside any struct is safe.

**Backing:** OpenZeppelin's zkSync Layer 1 Diff Audit, December 13, 2022, found a critical layout shift after a nested AppStorage struct changed size. That deployment used diamond AppStorage, not ERC-7201; the candidate applies the same layout rule inside a namespace. https://www.openzeppelin.com/news/zksync-layer-1-diff-audit

**Spec source:** ERC-7201 specifies ordinary layout rules within each namespace. https://eips.ethereum.org/EIPS/eip-7201#preliminaries

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### upgrades-storage-to-immutable
**Instruction:**
Does this change preserve the balances mapping? You are reviewing a proxy vault upgrade. V1 declares `uint256 public limit; mapping(address => uint256) balances;` in that order, with no other state or inheritance. V2 changes only limit to `uint256 public immutable limit`, assigns the same value in its constructor, and leaves balances next. No migration runs. Answer yes or no, then explain in one sentence.

**Answer:** No. The immutable takes no storage slot, so balances moves from slot 1 to slot 0 and reads different mapping locations.

**Why a model gets it wrong:** Models can treat immutable as a write restriction on the existing slot; likely known to a frontier model that tracks storage layout.

**Backing:** OpenZeppelin's Cubewire audit, published in 2026, records the team's rejection of a storage-to-immutable suggestion because it would shift proxy storage. This is a documented upgrade hazard, not an exploited loss. https://www.openzeppelin.com/news/cubewire-audit

**Spec source:** Solidity reserves no storage slot for constants or immutables. https://docs.soliditylang.org/en/latest/contracts.html#constant-and-immutable-state-variables

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

### upgrades-metamorphic-after-cancun
**Instruction:**
Can this proposal replace its code before execution on Ethereum mainnet after Cancun? You are reviewing a governance proposal contract deployed with CREATE2 before voting began. After voting closes, the attacker calls its SELFDESTRUCT path and plans to redeploy different runtime code at that address in a later transaction. The proposal is not a proxy. Answer yes or no, then explain in one sentence.

**Answer:** No. SELFDESTRUCT retains this old contract's code, so CREATE2 cannot redeploy over that occupied address.

**Why a model gets it wrong:** Models repeat the Tornado Cash metamorphic-proposal attack without checking whether the chain still permits its deletion step.

**Backing:** The May 20, 2023 Tornado Cash governance attack replaced an approved proposal through metamorphic deployment; Coinbase's investigation reports $3.2 million in losses. https://www.coinbase.com/blog/exploiting-governance-with-metamorphic-proposals

**Spec source:** https://eips.ethereum.org/EIPS/eip-6780#backwards-compatibility; https://eips.ethereum.org/EIPS/eip-1014#clarifications

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### upgrades-safe-module-threshold
**Instruction:**
Does a 3-of-5 Safe require three owner signatures for this upgrade? You are reviewing a vault whose ProxyAdmin belongs to the Safe. An enabled module permits one operator to submit arbitrary calls through `execTransactionFromModule`. No module guard restricts those calls. The operator submits ProxyAdmin's authorized upgrade call through that module. Answer yes or no, then explain in one sentence.

**Answer:** No. An enabled module executes under its own authorization rules without the Safe's ordinary owner-signature threshold.

**Why a model gets it wrong:** Models can equate Safe ownership with mandatory threshold approval on every execution path, though modules are likely known.

**Backing:** OpenZeppelin disclosed malicious deployment modules during its Augur work on March 12, 2020; the report demonstrates control without owner approval. No loss reported. https://www.openzeppelin.com/news/backdooring-gnosis-safe-multisig-wallets

**Spec source:** https://docs.safe.global/advanced/smart-account-modules#how-safe-modules-work

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### upgrades-explorer-hidden-delegation
**Instruction:**
Is matching the explorer's displayed implementation to the audit enough to approve this vault? You are reviewing an ERC-1967 proxy. Its raw implementation slot points to contract X, which the audit does not cover. X delegates ordinary calls to audited contract Y, and the explorer presents Y as the implementation. The ownership getter returns the expected Safe. Answer yes or no, then explain in one sentence.

**Answer:** No. Calls execute X before Y, so verified Y and an expected ownership getter do not establish X's behavior or authority.

**Why a model gets it wrong:** Models can treat an explorer's proxy association as a complete account of execution, but this warning is likely known.

**Backing:** USPD's preliminary post-mortem describes a hidden forwarding implementation installed September 16, 2025 and exploited December 4. It reports that explorers displayed the legitimate implementation while attacker code remained in the execution path. https://uspd.io/blog/cpimp-attack-postmortem

**Spec source:** The pinned ERC1967Proxy source resolves the implementation from storage before delegation. https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.6.0/contracts/proxy/ERC1967/ERC1967Proxy.sol

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** low

### upgrades-selfdestruct-still-transfers-eth
**Instruction:**
Can this execution still drain the proxy's ETH after Cancun? You are reviewing an Ethereum vault proxy deployed last year. An authorized path delegates into implementation code that executes SELFDESTRUCT with an attacker-controlled beneficiary. The transaction succeeds. The team argues that retained proxy code makes this harmless. Answer yes or no, then explain in one sentence.

**Answer:** Yes. SELFDESTRUCT still transfers the executing proxy account's entire ETH balance even though its code and storage remain.

**Why a model gets it wrong:** Models can overcorrect from old destruction semantics and assume the opcode became a no-op after Cancun.

**Backing:** OpenZeppelin's September 16, 2021 UUPS disclosure established the arbitrary-delegatecall-to-SELFDESTRUCT hazard; this candidate asks about its surviving ETH effect, not the old bricking outcome. The mitigation prevented known losses. https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680

**Spec source:** https://eips.ethereum.org/EIPS/eip-6780#specification

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** medium

### upgrades-create2-front-run-owner
**Instruction:**
Can the front-runner become the wallet's owner at Alice's predicted address? You are reviewing a public factory that uses CREATE2. The salt includes Alice's address. The creation code includes constructor arguments that initialize the wallet to Alice atomically. Ownership depends only on that explicit argument. An attacker submits the same factory call first, with identical salt and creation code. Ignore hash collisions. Answer yes or no, then explain in one sentence.

**Answer:** No. The copied deployment still assigns Alice as owner, although it can make her later duplicate deployment fail.

**Why a model gets it wrong:** Models can equate deployment front-running with ownership theft and miss the distinction between copied initialization and attacker-chosen initialization.

**Backing:** Hashlock's DB Cherry audit, May 2025, M-01, disclosed front-running denial of service in a CREATE2 wallet factory whose constructor data names the owner. No loss reported. https://hashlock.com/wp-content/uploads/2025/05/DB-Cherry-Smart-Contract-Audit-Report-Final-Report-v1.pdf

**Spec source:** https://eips.ethereum.org/EIPS/eip-1014#specification

**Grading:** pattern: starts with No

**Your confidence a frontier model fails cold:** medium

### upgrades-diamond-private-guard-slot
**Instruction:**
Can this facet overwrite the diamond's treasury value? You are reviewing a diamond whose treasury address occupies ordinary storage slot 0. A new facet inherits OpenZeppelin Contracts 4.9.6 ReentrancyGuard as its only state-bearing base. The facet uses `nonReentrant`, has no custom storage accessor, and runs through the diamond's delegatecall. The treasury value is not 2. Answer yes or no, then explain in one sentence.

**Answer:** Yes. ReentrancyGuard's private status variable also occupies slot 0 and its modifier writes that slot in the diamond's storage.

**Why a model gets it wrong:** Models can assume private library state or separate facet deployments isolate storage, or import the storage behavior of newer guards.

**Backing:** Hashlock's Kilma Protocol Main audit, April 2025, L-02, identified ordinary-slot ReentrancyGuard collisions across facets. The treasury example makes the reported future collision concrete; the report did not document a theft. https://hashlock.com/wp-content/uploads/2025/04/Kilma-Protocol-Main-Smart-Contract-Audit-Report-Final-Report-v3.pdf

**Spec source:** https://eips.ethereum.org/EIPS/eip-2535#storage; the cited audit identifies the guard's ordinary slot 0.

**Grading:** pattern: starts with Yes

**Your confidence a frontier model fails cold:** medium

## Rejected on the way

- Generic UUPS, transparent, and beacon trust questions are likely known; UUPS authorizes through implementation logic, transparent proxies through their admin, and beacons through the beacon's controller. https://docs.openzeppelin.com/contracts/5.x/api/proxy
- Mixing a UUPS implementation with a transparent proxy exposes an additional upgrade path, but I found no named incident for that exact combination. OpenZeppelin documents the warning. https://docs.openzeppelin.com/contracts/5.x/api/proxy#transparent-vs-uups-proxies
- A compromised upgrade key can replace withdrawal checks; Zoth lost about $8.4 million on March 21, 2025, but the plain question is too familiar. https://rekt.news/zoth-rekt
- UXLINK's September 22, 2025 delegatecall and owner-change sequence is verified in Blockscope's investigation; it does not establish a general Safe threshold bypass by one stolen key. https://research.blockscope.co/uxlink-exploit-analysis
- A 2025 stranger initializing an implementation remains unverified as an exploited incident; USPD concerns proxy hijacking, while Firelight report 59023 is an audit submission, not proof of a production attack. https://reports.immunefi.com/firelight/59023-sc-low-unprotected-implementation-contract-initializer-allows-unauthorized-admin-role-assignme
- Storage gaps and packed fields offer precise questions, but I found no incident or audit finding for the exact packing mistake within the budget. https://docs.openzeppelin.com/upgrades-plugins/writing-upgradeable#storage-gaps
- ERC-7201 prevents overlap between distinct namespace roots; it does not repair edits within a namespace, which the retained nested-struct candidate covers. https://eips.ethereum.org/EIPS/eip-7201
- Constants and implementation immutables consume no proxy storage; shared immutable values alone are too familiar and lacked a stronger incident link. https://docs.soliditylang.org/en/latest/contracts.html#constant-and-immutable-state-variables
- Constructor-only initialization of proxy state is too familiar; the retained constructor candidate asks about a versioned initialization loophole instead. https://docs.openzeppelin.com/upgrades-plugins/writing-upgradeable
- Same-transaction SELFDESTRUCT deletion remains an EIP-6780 exception; I found no specific incident that supports a practical deployment question beyond the retained examples. https://eips.ethereum.org/EIPS/eip-6780#specification
- Ownable's explicit initialOwner and transferOwnership versus Ownable2Step are likely known; the retained ProxyAdmin case uses a less familiar ownership consequence. https://docs.openzeppelin.com/contracts/5.x/access-control#ownership-and-ownable
- OpenZeppelin 5.x `_update`, Address.isContract removal, and ReentrancyGuardTransient need exact incident or audit backing; I did not establish that backing within the budget, so I did not invent candidates.
- A pinned CREATE2 address does not by itself prove constructor behavior or later proxy behavior; the retained front-running question has a tighter audit match. https://eips.ethereum.org/EIPS/eip-1014
