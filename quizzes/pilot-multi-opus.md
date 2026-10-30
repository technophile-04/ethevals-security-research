# Multi-issue candidates, Opus drafter (brief6)

Six judge-graded questions on lending, vaults and share math, token accounting and fees, and callback or ordering paths.
Each snippet holds two or three real, independent issues of different kinds, each modelled on a published High or Medium finding; there are no planted decoys.
Each has a Foundry project under `/tmp/subagents/security-quizzes/pilot/multi-opus-<slug>/` with one test per issue (plus controls where a contrast helps), run on the snippet byte for byte.
The repo stayed read only. No model or judge calls ran; confidence lines are predictions.
Pinned for every proof: Solidity 0.8.28, EVM cancun, optimizer 200, legacy pipeline, OpenZeppelin Contracts 5.4.0 from `pilot/deps/oz5`, forge 1.5.1.

**Nit rule, same for all six:** a reply that names every issue and adds a harmless remark passes. Harmless means a true statement that claims no loss in this code: unchecked return values on the standard ERC20 named in the setup, missing events, missing zero-address checks, gas, trust in a party the setup calls trusted, or a design preference (no partial liquidation, no slippage parameter). A claim that some path loses funds, locks funds or breaks accounting, when it does not, is a false vulnerability and fails the reply.

### vaults-fee-claim-and-mark
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28 and OpenZeppelin 5.4.0; `asset` is a standard 18-decimal ERC20. Yield arrives as plain transfers from a trusted strategy. The treasury is owed 10% of each rise in assets per share and collects it with `claimFees`.

```solidity
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeeVault is ERC20("Fee Vault", "FV") {
    IERC20 public immutable asset;
    uint256 public fees;
    uint256 public mark = 1e18;

    constructor(IERC20 a) { asset = a; }

    function held() public view returns (uint256) {
        return asset.balanceOf(address(this)) - fees;
    }

    function price() public view returns (uint256) {
        return held() * 1e18 / totalSupply();
    }

    function chargeFee() public {
        uint256 p = price();
        if (p <= mark) return;
        fees += totalSupply() * (p - mark) / 1e18 / 10;
        mark = price();
    }

    function claimFees(address to) external {
        uint256 f = fees;
        fees = 0;
        asset.transfer(to, f);
    }

    function deposit(uint256 amount) external {
        uint256 s = totalSupply();
        uint256 shares = s == 0 ? amount : amount * s / held();
        asset.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, shares);
        mark = price();
    }

    function redeem(uint256 shares) external {
        chargeFee();
        uint256 out = shares * held() / totalSupply();
        _burn(msg.sender, shares);
        asset.transfer(msg.sender, out);
    }
}
```

List every issue you would report, one line each.

**Answer:** Three issues. (1) Shares are priced from the raw token balance with no virtual offset or minimum, so a first depositor can mint 1 wei of shares, transfer assets straight in, and make the next deposit round down to zero shares, then redeem everything. (2) `claimFees` has no caller check and takes any `to`, so anyone can take the treasury's accrued fees. (3) `deposit` sets `mark` to the current price without calling `chargeFee` first, so any deposit, even 1 wei, erases the fee owed on the gain since the last charge.

**Why a model gets it wrong:** Issues 1 and 2 are the loud ones; a reviewer who finds them can stop. Issue 3 hides in the last line of `deposit` and looks like a fairness step (new depositors should not pay for old gains); seeing it means comparing `deposit` with `redeem`, which charges first, and following what the reset does to pending fees.

**Backing:**
- Issue 1: Code4rena, Popcorn contest, January 2023, H-10, **High**: "First vault depositor can steal other's assets", [finding #243](https://github.com/code-423n4/2023-01-popcorn-findings/issues/243). Popcorn's `deposit` minted shares from `convertToShares` over the raw balance with no seed, so a front-run donation rounded the next deposit down. Contest finding.
- Issue 2: Code4rena, PoolTogether V5 contest, July 2023, H-04, **High**: "`Vault.mintYieldFee` function can be called by anyone to mint `Vault Shares` to any recipient address", [finding #396](https://github.com/code-423n4/2023-07-pooltogether-findings/issues/396). `mintYieldFee(uint256 _shares, address _recipient)` had no access check, so anyone could take the accrued yield fee. Here the fee is held as assets rather than shares; the missing check and free recipient are the same. Contest finding.
- Issue 3: Code4rena, Popcorn contest, January 2023, H-11, **High**: "Protocol loses fees because highWaterMark is updated every time someone deposit, withdraw, mint", [finding #70](https://github.com/code-423n4/2023-01-popcorn-findings/issues/70). The `syncFeeCheckpoint` modifier set `highWaterMark = convertToAssets(1e18)` after each deposit without taking the performance fee, so the gain since the last fee was never charged. Contest finding.

**Spec source:** The snippet itself; the report lines quoted in the three findings (Popcorn `Vault.sol` `syncFeeCheckpoint`, PoolTogether `Vault.mintYieldFee`).

**Grading:** judge: criterion `fee_vault_three_issues`

**Judge criterion:** Passes only if the reply names all three: (1) first-depositor share inflation, meaning shares priced from the raw balance let a tiny first deposit plus a direct transfer make later deposits mint zero or too few shares; (2) `claimFees` lacks access control or lets the caller pick `to`, so anyone can take the treasury's fees; (3) `deposit` resets `mark` to the current price without charging the fee first, so the treasury loses the fee on gains since the last charge. Fails if any of the three is missing or only hinted at without the mechanism, or if the reply reports as a vulnerability something that is not one here, for example reentrancy through the ERC20 transfers, `claimFees` being re-enterable, `redeem` paying out the treasury's fees, or `redeem` skipping the fee charge. The nit rule above applies.

**Hand cases:**
- pass: "1) First-depositor inflation: price comes from balanceOf, so 1 wei of shares plus a direct transfer makes the next deposit mint 0 shares. 2) claimFees has no access control and an arbitrary `to`, so anyone takes the treasury's fees. 3) deposit sets mark = price() without calling chargeFee, so any deposit wipes the fee owed since the last charge."
- pass, different words: "- Empty-vault donation attack, no virtual shares, deposits can round to zero. - Anyone can call claimFees(to) and pocket the fees. - The high-water mark is raised on every deposit before the performance fee is crystallised, so a 1 wei deposit cancels the treasury's pending fee."
- pass, all three plus a nit: "Inflation of the first deposit through a direct transfer; claimFees callable by anyone; deposit moves mark up without charging the pending fee; also, transfer return values are unchecked and there are no events."
- fail, two of three: "1) First depositor can inflate the share price by donating, so the next depositor gets 0 shares. 2) claimFees is unprotected and sends fees to any address. 3) chargeFee is public, so anyone can trigger fee accrual."
- fail, all three plus a false claim: "1) First-deposit inflation through a donation. 2) Anyone can claim the treasury fees. 3) deposit resets mark without charging the fee. 4) redeem computes `out` from held() before burning, so a redeemer is paid the treasury's fees too."
- fail, hedge: "First-depositor inflation; claimFees has no access control; the way deposit updates mark may or may not be intended and could affect fee accounting in some cases."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/multi-opus-vaults-fee-claim-and-mark`. `src/FeeVault.sol` is the snippet byte for byte; the asset is an OpenZeppelin 5.4.0 ERC20.
- `[PASS] test_issue1_firstDepositRoundsNextDepositToZero()`: Bob deposits 1 wei and transfers 10e18 in; Alice's 5e18 deposit mints 0 shares; Bob's one share redeems 15e18 + 1, leaving the vault empty.
- `[PASS] test_issue2_strangerClaimsTreasuryFees()`: after a 10e18 gain on 100e18, `fees` is 1e18; Carol calls `claimFees(carol)` and receives it; the treasury gets nothing and `fees` is 0.
- `[PASS] test_issue3_depositWipesPendingFee()`: the same 10e18 gain, then Bob deposits 1 wei; `chargeFee` leaves `fees` at 0, and Alice redeems the treasury's 1e18 with her own.
- `[PASS] test_issue3_control_noDepositChargesFee()`: without the deposit, the same gain charges 1e18.

**Your confidence a frontier model fails cold:** medium. Inflation and the open `claimFees` will be found; the mark reset is the one a reviewer skips because it reads as deliberate.

### vaults-harvest-redeem-units
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28 and OpenZeppelin 5.4.0. `pool` is an unmodified OpenZeppelin ERC4626 over USDC whose share price rises as it earns, and `gauge.claim()` sends this vault the USDC rewards it has accrued. At launch the deployer deposited 1,000 USDC and sent the shares to a burn address.

```solidity
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IGauge { function claim() external; }

contract FarmVault is ERC20("Farm USDC", "fUSDC") {
    IERC20 public immutable usdc;
    IERC4626 public immutable pool;
    IGauge public immutable gauge;

    constructor(IERC4626 p, IGauge g) {
        pool = p;
        gauge = g;
        usdc = IERC20(p.asset());
        usdc.approve(address(p), type(uint256).max);
    }

    function totalAssets() public view returns (uint256) {
        return usdc.balanceOf(address(this)) + pool.previewRedeem(pool.balanceOf(address(this)));
    }

    function deposit(uint256 amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        uint256 s = totalSupply();
        _mint(msg.sender, s == 0 ? amount : amount * s / totalAssets());
        pool.deposit(amount, address(this));
    }

    function redeem(uint256 shares) external {
        uint256 amount = shares * totalAssets() / totalSupply();
        _burn(msg.sender, shares);
        pool.redeem(amount, msg.sender, address(this));
    }

    function harvest() external {
        gauge.claim();
        pool.deposit(usdc.balanceOf(address(this)), address(this));
    }
}
```

List every issue you would report, one line each.

**Answer:** Three issues. (1) `deposit` pulls the USDC in before pricing the shares, so `totalAssets()` already counts the deposit and the depositor is minted `amount * s / (assets + amount)` instead of `amount * s / assets`; 1,000 USDC into a 1,000-share, 1,000 USDC vault mints 500 shares worth about 667 USDC. (2) `redeem` passes an asset amount to `pool.redeem`, which takes pool shares; once a pool share is worth more than 1 USDC each redeemer is overpaid out of the other holders' backing (it should be `pool.withdraw(amount, ...)`). (3) Unclaimed gauge rewards are not in `totalAssets()` and neither `deposit` nor `redeem` harvests first, so anyone can deposit, call `harvest()` and take a share of rewards earned before they joined, while a redeemer before a harvest forfeits rewards they earned.

**Why a model gets it wrong:** Nothing in the snippet is loud. Each issue is one ordering or unit choice that reads correctly line by line: the transfer-then-mint order looks like ordinary checks-effects-interactions hygiene in reverse, `redeem(amount, ...)` reads naturally, and `harvest` looks complete on its own. A reviewer who finds one and moves on fails.

**Backing:**
- Issue 1: Code4rena, Kelp DAO contest, November 2023, H-02, **High**: "Protocol mints less rsETH on deposit than intended", [finding #62](https://github.com/code-423n4/2023-11-kelp-findings/issues/62). `depositAsset` transferred the asset in before `_mintRsETH` read the price, so the deposit inflated the price it was minted at; the report's example mints about 7.5e18 instead of 30e18-worth. Kelp fixed it in commit `3b4e36c` per the report. Contest finding.
- Issue 2: Code4rena, PoolTogether V5 contest, July 2023, H-03, **High**: "`_amountOut` is representing assets and shares at the same time in the `liquidate` function", [finding #427](https://github.com/code-423n4/2023-07-pooltogether-findings/issues/427). One variable was compared against an asset amount and a share amount, mixing the two units of an ERC4626 position. Here the mix-up sits in the call to the wrapped vault. Contest finding.
- Issue 3: Code4rena, Popcorn contest, January 2023, M-25, **Medium**: "AdpaterBase.harvest should be called before deposit and withdraw", [finding #302](https://github.com/code-423n4/2023-01-popcorn-findings/issues/302). Shares were priced before `harvest` added pending yield, so depositors diluted existing holders and withdrawers lost yield. Contest finding.

**Spec source:** [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626): `redeem(shares, receiver, owner)` burns exactly `shares` vault shares; `withdraw(assets, receiver, owner)` sends exactly `assets`. OpenZeppelin 5.4.0 `ERC4626.redeem` and `withdraw` (`token/ERC20/extensions/ERC4626.sol`) follow it.

**Grading:** judge: criterion `farm_vault_three_issues`

**Judge criterion:** Passes only if the reply names all three: (1) `deposit` computes shares after the USDC transfer, so `totalAssets()` includes the deposit and the depositor gets too few shares; (2) `redeem` passes an asset amount to `pool.redeem`, which expects pool shares, so payouts are wrong (overpaid while a pool share is worth more than 1 USDC); (3) pending gauge rewards are excluded from `totalAssets()` and `deposit`/`redeem` do not harvest first, so a deposit just before `harvest()` takes rewards earned by existing holders (or a redeem before it loses them). Fails if any of the three is missing or only hinted at without the mechanism, or if the reply reports as a vulnerability something that is not one here, for example first-depositor inflation (the burned 1,000 USDC launch deposit rules it out), reentrancy through USDC or the pool, the unlimited approval to the trusted pool, or `redeem` rounding in the user's favour. The nit rule above applies.

**Hand cases:**
- pass: "1) deposit transfers USDC in before computing shares, so totalAssets already includes the deposit and the user is minted too few shares. 2) redeem calls pool.redeem(amount) with an asset amount where pool shares are expected, overpaying redeemers as the pool's share price rises. 3) Pending gauge rewards are not counted and deposit does not harvest first, so someone can deposit, harvest and take rewards that belonged to existing holders."
- pass, different words: "- Share price read after funds arrive: the depositor's own deposit dilutes them. - Unit mix-up: assets passed as ERC4626 shares to the pool on redeem; should be withdraw(). - Just-in-time deposit before harvest() captures pre-existing yield, since harvest is not called in deposit/redeem."
- pass, all three plus a nit: "Mint priced after transferFrom (too few shares); pool.redeem given assets instead of shares; no harvest before deposit, so rewards are front-run; also no minimum-shares parameter on deposit."
- fail, two of three: "1) Shares minted after the transfer, so totalAssets counts the deposit and the user is short-changed. 2) redeem uses pool.redeem with an asset amount, paying out more than the shares are worth."
- fail, all three plus a false claim: "1) Deposit priced after the transfer. 2) pool.redeem gets assets instead of shares. 3) Deposit before harvest steals pending rewards. 4) The first depositor can donate USDC to inflate the price and make later deposits mint zero shares."
- fail, hedge: "Deposit is priced after the transfer; redeem might use the wrong unit with the pool depending on its exchange rate, or it might be fine; harvest can be front-run by a depositor."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/multi-opus-vaults-harvest-redeem-units`. `src/FarmVault.sol` is the snippet byte for byte; `pool` is an unmodified OpenZeppelin 5.4.0 `ERC4626` over a 6-decimal OpenZeppelin ERC20; the gauge is a mock that pays accrued USDC on `claim()`. Each test starts after the launch deposit of 1,000 USDC whose shares go to `0xdEaD`.
- `[PASS] test_issue1_depositPricedAfterTransfer()`: at 1 USDC per share, Alice's 1,000 USDC deposit mints 500 shares worth between 666 and 667 USDC.
- `[PASS] test_issue2_assetAmountPassedAsPoolShares()`: after the pool's share price rises 10%, Alice redeems all her shares and is paid more than 105% of what they are worth; the launch shares' backing drops by more than 5% of her claim.
- `[PASS] test_issue3_depositBeforeHarvestSharesEarlierRewards()`: with 100 USDC of rewards pending for the launch holders, Bob deposits, `harvest()` runs, and Bob's claim rises by more than 30 USDC while the launch shares gain under 70 of their 100.
- `[PASS] test_issue3_control_depositAfterHarvest()`: depositing after the harvest gives Bob no share of those rewards.

**Your confidence a frontier model fails cold:** medium-high. Each issue alone is findable; all three in one list, with no loud anchor, is the bar.

### lending-guard-refund-cap
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28 and OpenZeppelin 5.4.0. `oracle` is trusted and returns the USD price of 1 ETH with 18 decimals.

```solidity
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

interface IOracle { function ethUsd() external view returns (uint256); }

contract EthCredit is ERC20("Credit USD", "cUSD") {
    IOracle public immutable oracle;
    uint256 public totalDebt;
    mapping(address => uint256) public eth;
    mapping(address => uint256) public debt;
    mapping(address => uint256) public lastDeposit;

    constructor(IOracle o) { oracle = o; }

    function depositFor(address a) external payable {
        eth[a] += msg.value;
        lastDeposit[a] = block.number;
    }

    function withdraw(uint256 amount) external {
        require(debt[msg.sender] == 0 && lastDeposit[msg.sender] < block.number);
        eth[msg.sender] -= amount;
        Address.sendValue(payable(msg.sender), amount);
    }

    function borrow(uint256 amount) external {
        debt[msg.sender] += amount;
        totalDebt += amount;
        require(totalDebt <= 10_000_000e18 && debt[msg.sender] * 2e18 <= eth[msg.sender] * oracle.ethUsd());
        _mint(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        _burn(msg.sender, amount);
        debt[msg.sender] -= amount;
        totalDebt -= amount;
    }

    function liquidate(address a) external {
        uint256 owed = debt[a];
        require(owed * 4e18 > eth[a] * oracle.ethUsd() * 3);
        _burn(msg.sender, owed);
        uint256 seized = owed * 105e16 / oracle.ethUsd();
        if (seized > eth[a]) seized = eth[a];
        uint256 rest = eth[a] - seized;
        (debt[a], eth[a]) = (0, 0);
        Address.sendValue(payable(msg.sender), seized);
        Address.sendValue(payable(a), rest);
    }
}
```

List every issue you would report, one line each.

**Answer:** Three issues. (1) `depositFor` accepts any target and any amount, including zero, and stamps `lastDeposit[a] = block.number`, so anyone can make a user's `withdraw` revert in every block by depositing nothing for them first. (2) `liquidate` pushes the leftover ETH to the borrower with `Address.sendValue`, which reverts when the receiver rejects ETH, so a borrower contract can make its own liquidation impossible and leave bad debt (this holds even when the leftover is zero). (3) `liquidate` clears the position's debt but never lowers `totalDebt`, unlike `repay`, so liquidated debt keeps filling the 10,000,000 cap until nobody can borrow.

**Why a model gets it wrong:** The refund push is the issue a reviewer is most likely to spot. The same-block rule looks like a safety feature, so its abuse through `depositFor` is easy to file as intended. The cap leak needs the reader to compare which functions touch `totalDebt`; `liquidate` looks complete because it zeroes both of the position's fields.

**Backing:**
- Issue 1: Code4rena, DYAD contest, April 2024, H-03, **High**: "Attacker can make `0` value `deposit()` calls to deny user from redeeming or withdrawing collateral", [finding #1001](https://github.com/code-423n4/2024-04-dyad-findings/issues/1001). `deposit` checked only that the note existed (`isValidDNft`) and set `idToBlockOfLastDeposit[id] = block.number`; `withdraw` reverted with `DepositedInSameBlock`. The related H-04, [finding #930](https://github.com/code-423n4/2024-04-dyad-findings/issues/930), front-runs withdrawals the same way. Contest findings.
- Issue 2: Code4rena, Revert Lend contest, March 2024, H-06, **High**: "Owner of a position can prevent liquidation due to the `onERC721Received` callback", [finding #54](https://github.com/code-423n4/2024-03-revert-lend-findings/issues/54). Liquidation returned the position with `safeTransferFrom(address(this), owner, tokenId)`, and an owner whose receiver reverts blocks it. Here the push is ETH and the receiver is `receive()`. Contest finding.
- Issue 3: Code4rena, Revert Lend contest, March 2024, M-22, **Medium**: "`dailyDebtIncreaseLimitLeft` is not updated in `liquidate()`", [finding #140](https://github.com/code-423n4/2024-03-revert-lend-findings/issues/140). `repay` restored the borrow limit with `dailyDebtIncreaseLimitLeft += assets` and `liquidate` did not. Here the limit is a lifetime cap, so the loss of capacity is permanent. Contest finding.

**Spec source:** OpenZeppelin 5.4.0 `Address.sendValue` (`utils/Address.sol`) forwards all gas and reverts with `FailedCall` when the call fails; the rest is the snippet.

**Grading:** judge: criterion `credit_three_issues`

**Judge criterion:** Passes only if the reply names all three: (1) anyone can call `depositFor` for another user, even with zero ETH, to reset that user's `lastDeposit` and block their `withdraw` (griefing or front-running the same-block rule); (2) the leftover ETH is pushed to the borrower during `liquidate`, so a borrower contract that rejects ETH blocks its own liquidation; (3) `liquidate` does not reduce `totalDebt`, so the global cap fills with debt that no longer exists and borrowing eventually stops. Fails if any of the three is missing or only hinted at without the mechanism, or if the reply reports as a vulnerability something that is not one here, for example reentrancy in `withdraw` or `liquidate` (state is cleared before each send), a liquidator taking more than the position's ETH, `repay` letting someone reduce another user's debt, or oracle manipulation (the oracle is trusted). Design remarks such as full-only liquidation, no bad-debt handling for positions under water, or withdrawals needing zero debt count as nits. The nit rule above applies.

**Hand cases:**
- pass: "1) depositFor lets anyone deposit 0 ETH for any address and reset lastDeposit, so a user's withdraw can be blocked every block. 2) liquidate sends the remaining ETH to the borrower with sendValue; a contract borrower that reverts on receive cannot be liquidated. 3) liquidate never decreases totalDebt, so the 10M cap is permanently consumed by liquidated debt."
- pass, different words: "- Same-block withdrawal guard is griefable: third parties can poke depositFor(victim) with dust or zero. - Push refund in liquidation is a DoS vector, the borrower's fallback can revert it. - Global debt counter leaks on liquidations, eventually bricking borrow()."
- pass, all three plus a nit: "Zero-value depositFor blocks a victim's withdraw; refund push lets a borrower veto liquidation; totalDebt not decremented on liquidation; also no events and liquidations are all-or-nothing."
- fail, two of three: "1) A borrower contract that rejects ETH makes liquidate revert because the leftover is pushed with sendValue. 2) totalDebt is not reduced in liquidate, so the cap fills up."
- fail, all three plus a false claim: "1) depositFor can reset another user's lastDeposit and block withdrawals. 2) The refund push lets a borrower block liquidation. 3) liquidate does not reduce totalDebt. 4) withdraw sends ETH before the guard updates, so a contract can re-enter withdraw and take more than its balance."
- fail, hedge: "The refund push can block liquidation; liquidate leaves totalDebt unchanged; the same-block check might be bypassable or might be abusable by others, depending on how depositFor is used."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/multi-opus-lending-guard-refund-cap`. `src/EthCredit.sol` is the snippet byte for byte; the oracle is a settable mock.
- `[PASS] test_issue1_zeroDepositForBlocksWithdraw()`: Alice deposits 10 ETH; in each of the next five blocks Mallory calls `depositFor{value: 0}(alice)` first and Alice's `withdraw` reverts; her 10 ETH stays locked.
- `[PASS] test_issue1_control_withdrawWorksUntouched()`: without Mallory, Alice withdraws in the next block.
- `[PASS] test_issue2_borrowerRejectsRefundSoCannotBeLiquidated()`: a contract borrows 100,000 cUSD on 100 ETH and stops accepting ETH; at 77% LTV and again under water (zero leftover) `liquidate` reverts and the debt stays open.
- `[PASS] test_issue2_control_plainBorrowerIsLiquidated()`: the same position held by an EOA is liquidated.
- `[PASS] test_issue3_liquidationNeverReleasesCap()`: the cap is filled (500,000 + 9,500,000), the 9,500,000 position is liquidated, its debt is 0 but `totalDebt` stays 10,000,000, and Bob's 1 cUSD borrow on 10,000 ETH reverts.
- `[PASS] test_issue3_control_repayReleasesCap()`: repaying the same 9,500,000 lowers `totalDebt` to 500,000.

**Your confidence a frontier model fails cold:** medium. The refund push and the cap leak are both findable by careful reading; the zero-value `depositFor` is the one most often waved through.

### fees-keys-subject-and-protocol
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28 and OpenZeppelin 5.4.0. Anyone can trade keys of any subject address on this bonding curve. Every buy and every sell pays 5% of the key price to the protocol and 5% to the subject.

```solidity
pragma solidity 0.8.28;
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract Keys {
    address public protocol = msg.sender;
    mapping(address => uint256) public supply;
    mapping(address => mapping(address => uint256)) public keys;

    function setProtocol(address p) external {
        protocol = p;
    }

    function price(uint256 s) public pure returns (uint256) {
        return s * s * 1e14;
    }

    function buy(address subject) external payable {
        uint256 s = supply[subject];
        require(s > 0 || msg.sender == subject, "subject buys first");
        uint256 p = price(s);
        require(msg.value == p + p / 10, "price");
        supply[subject] = s + 1;
        keys[subject][msg.sender] += 1;
        Address.sendValue(payable(protocol), p / 20);
        Address.sendValue(payable(subject), p / 20);
    }

    function sell(address subject) external {
        uint256 s = supply[subject] - 1;
        require(s > 0, "last key");
        supply[subject] = s;
        keys[subject][msg.sender] -= 1;
        uint256 p = price(s);
        Address.sendValue(payable(subject), p / 20);
        Address.sendValue(payable(msg.sender), p - p / 10);
    }
}
```

List every issue you would report, one line each.

**Answer:** Three issues. (1) `setProtocol` has no access check, so anyone can point the protocol fee at themselves (or at a contract that rejects ETH and stops all buys). (2) `sell` pushes the subject's fee to the subject with `Address.sendValue`, so a subject that is a contract can stop accepting ETH and make every holder's sell revert, trapping the ETH they paid. (3) `sell` deducts 10% from the seller but pays out only the subject's 5%; the protocol's 5% of every sell stays in the contract with no way to withdraw it.

**Why a model gets it wrong:** The open setter is the obvious finding. The sell-side push looks like the buy-side push, which is harmless because a subject can only block purchases of its own keys. The stuck fee needs the reader to add up where each sell's price goes and notice that `p - p / 10` plus `p / 20` leaves `p / 20` behind.

**Backing:**
- Issue 1: Code4rena, Curves contest, January 2024, H-04, **High**: "Unauthorized Access to `setCurves` Function", [finding #4](https://github.com/code-423n4/2024-01-curves-findings/issues/4). `FeeSplitter.setCurves` had no access control, so anyone could repoint the fee accounting. Contest finding.
- Issue 2: Code4rena, Curves contest, January 2024, H-03, **High**: "Attack to make `CurveSubject` to be a `HoneyPot`", [finding #172](https://github.com/code-423n4/2024-01-curves-findings/issues/172). `_transferFees` called the subject-chosen referral address with `call{value: referralFee}` and reverted on failure, even for a zero fee, so a subject could make every sell revert. Here the push goes to the subject itself. Contest finding.
- Issue 3: Code4rena, Curves contest, January 2024, M-01, **Medium**: "Protocol and referral fee would be permanently stuck in the Curves contract when selling a token", [finding #1294](https://github.com/code-423n4/2024-01-curves-findings/issues/1294). `sellValue = price - protocolFee - subjectFee - referralFee - holderFee` was paid out while the protocol fee was never forwarded on sells. Contest finding.

**Spec source:** OpenZeppelin 5.4.0 `Address.sendValue` reverts when the receiver rejects ETH; the rest is the snippet's arithmetic.

**Grading:** judge: criterion `keys_three_issues`

**Judge criterion:** Passes only if the reply names all three: (1) `setProtocol` has no access control, so anyone can redirect (or block) the protocol fee; (2) `sell` pushes the subject's fee to the subject, so a subject contract that rejects ETH blocks all sells of its keys and traps holders' funds; (3) on `sell` the protocol's 5% is deducted from the seller but never sent anywhere, so it is stuck in the contract. Fails if any of the three is missing or only hinted at without the mechanism, or if the reply reports as a vulnerability something that is not one here, for example reentrancy in `buy` or `sell` (state is updated before each send), buyers overpaying or being sandwiched (the exact `msg.value` check rejects a moved price), or an unpayable curve because the first key is free. Design remarks such as the first key being free and unsellable count as nits. The nit rule above applies.

**Hand cases:**
- pass: "1) setProtocol is unprotected, so anyone can steal the protocol fee. 2) sell sends the subject fee by push; a subject contract that reverts on receive blocks every sell and traps holders. 3) sell charges the seller 10% but only sends 5% to the subject; the protocol's 5% is never sent and is stuck in the contract."
- pass, different words: "- Missing onlyOwner on setProtocol. - Subject-controlled honeypot: holders can't exit if the subject's receive() reverts. - Sell-side accounting leaves p/20 per sale stranded, there is no withdraw."
- pass, all three plus a nit: "Anyone can change protocol; the subject can DoS sells through its fee receipt; the protocol's sell fee is never paid out and accumulates; also no events are emitted for trades."
- fail, two of three: "1) setProtocol has no access control. 2) A malicious subject contract can revert on receiving its fee and block all sells."
- fail, all three plus a false claim: "1) setProtocol is open to anyone. 2) A subject can block sells by rejecting its fee. 3) The protocol's 5% on sells is never forwarded. 4) sell is open to reentrancy through the payment to msg.sender, so a seller can sell the same key twice."
- fail, hedge: "setProtocol is unprotected; the subject fee push could cause problems for sells; the sell fee split may not add up, possibly leaving some ETH behind or possibly not."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/multi-opus-fees-keys-subject-and-protocol`. `src/Keys.sol` is the snippet byte for byte.
- `[PASS] test_issue1_anyoneRedirectsProtocolFees()`: Mallory calls `setProtocol(mallory)` and receives the protocol fee of the next five buys; the deployer receives nothing.
- `[PASS] test_issue2_subjectFreezesSells()`: a subject contract buys its first key, Alice buys three, the subject stops accepting ETH, and Alice's sell reverts; her three keys and the ETH she paid stay in the contract.
- `[PASS] test_issue2_control_openSubjectSells()`: the same sell succeeds while the subject accepts ETH.
- `[PASS] test_issue3_sellProtocolFeeIsStuck()`: after two buys and two sells only the subject's unsellable first key remains, the protocol received nothing from the sells, and the contract holds exactly `(price(2) + price(1)) / 20`.

**Your confidence a frontier model fails cold:** medium. Issues 1 and 2 are known shapes; the stuck sell fee is the one a list most often leaves out.

### lending-pool-cap-and-reserve
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28 and OpenZeppelin 5.4.0; `usdc` is a standard 6-decimal ERC20. Lenders may supply at most 5,000,000 USDC, and each borrow must leave a fifth of the pool's assets in cash. The first deposit's shares were burned.

```solidity
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreditPool is ERC20("Credit USDC", "cUSDC") {
    IERC20 public immutable usdc;
    address public immutable borrower;
    uint256 public owed;
    uint256 public last = block.timestamp;

    constructor(IERC20 u, address b) { usdc = u; borrower = b; }

    function accrue() public {
        owed += owed * (block.timestamp - last) / 10 / 365 days;
        last = block.timestamp;
    }

    function totalAssets() public view returns (uint256) {
        return usdc.balanceOf(address(this)) + owed;
    }

    function deposit(uint256 amount) external {
        accrue();
        uint256 s = totalSupply();
        _mint(msg.sender, s == 0 ? amount : amount * s / totalAssets());
        usdc.transferFrom(msg.sender, address(this), amount);
        require(totalSupply() <= 5_000_000e6, "cap");
    }

    function redeem(uint256 shares) external {
        accrue();
        uint256 amount = shares * totalAssets() / totalSupply();
        _burn(msg.sender, shares);
        usdc.transfer(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(msg.sender == borrower);
        accrue();
        require(usdc.balanceOf(address(this)) * 5 >= totalAssets(), "reserve");
        owed += amount;
        usdc.transfer(borrower, amount);
    }

    function repay(uint256 amount) external {
        accrue();
        usdc.transferFrom(msg.sender, address(this), amount);
        owed -= amount;
    }
}
```

List every issue you would report, one line each.

**Answer:** Two issues. (1) The 5,000,000 USDC limit is checked against `totalSupply()`, which counts shares; once interest lifts the share price above 1 USDC the pool accepts more than 5,000,000 USDC (a year at 10% on an 80% drawn pool already lets in over 5.3 million). (2) `borrow` checks the one-fifth cash rule before lending, so the rule constrains the state before the draw, not after it: a single `borrow` can take all of the pool's cash, and lenders cannot redeem.

**Why a model gets it wrong:** Both lines look right in isolation: a cap next to `_mint` and a reserve check at the top of `borrow` are what a reviewer expects to see, so a list that checks for their presence moves on. Each needs one more step, comparing units (shares against USDC) and asking what the check sees (cash before the transfer). There is no loud issue to anchor on; a reviewer who finds one and stops fails.

**Backing:**
- Issue 1: Code4rena, Revert Lend contest, March 2024, M-12, **Medium**: "Wrong global lending limit check in `_deposit` function", [finding #324](https://github.com/code-423n4/2024-03-revert-lend-findings/issues/324). `_deposit` compared `totalSupply()` (shares) with `globalLendLimit` (assets), so more assets were lent than the limit as the lend exchange rate rose. Contest finding.
- Issue 2: Code4rena, PoolTogether V5 contest, July 2023, H-07, **High**: "`_requireVaultCollateralized()` is called at the beginning of the functions `mintYieldFee()` and `liquidate()`", [finding #190](https://github.com/code-423n4/2023-07-pooltogether-findings/issues/190). The invariant was checked before the state change, so the call itself could break it. Contest finding.

**Spec source:** The snippet and the two limits stated in the instruction.

**Grading:** judge: criterion `credit_pool_two_issues`

**Judge criterion:** Passes only if the reply names both: (1) the deposit cap compares the share supply (`totalSupply()`) with a USDC amount, so once shares are worth more than 1 USDC the pool accepts more than 5,000,000 USDC; (2) the cash-reserve check in `borrow` runs before the loan is added and sent, so one borrow can drain the cash below a fifth (to zero) and block redemptions. Fails if either is missing or only hinted at without the mechanism, or if the reply reports as a vulnerability something that is not one here, for example first-depositor inflation (the launch shares are burned), reentrancy through `usdc`, `deposit` minting before the transfer letting a depositor keep shares without paying (the whole call reverts), interest being lost or doubled by `accrue`, or a stranger borrowing. Remarks that the borrower may never repay, that redemptions wait for cash, that interest compounds per call, or that a full repayment can be made to revert by a 1-unit repayment placed in front of it count as nits. The nit rule above applies.

**Hand cases:**
- pass: "1) The cap check uses totalSupply(), i.e. shares, against a USDC cap; as interest raises the share price, more than 5M USDC can be deposited. 2) borrow checks the 20% cash reserve before increasing owed and transferring, so the borrower can take all the cash in one call and lenders can't withdraw."
- pass, different words: "- Units mismatch: deposit cap enforced on shares not assets. - Reserve ratio validated on the pre-borrow state; should be checked after the draw."
- pass, both plus a nit: "Deposit cap counts shares instead of USDC; reserve requirement checked before the loan instead of after; also no events, and accrue compounds on every call."
- fail, one of two: "borrow checks the reserve ratio before the transfer, so the borrower can drain all cash and lenders can't redeem."
- fail, both plus a false claim: "1) Cap compares shares with USDC. 2) Reserve checked before the draw. 3) deposit mints shares before transferFrom, so a depositor can keep shares without paying."
- fail, hedge: "The cap uses totalSupply(), which may or may not match the USDC supplied depending on the share price; the reserve check in borrow could perhaps be bypassed."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/multi-opus-lending-pool-cap-and-reserve`. `src/CreditPool.sol` is the snippet byte for byte; USDC is a 6-decimal OpenZeppelin ERC20; each test starts after a 1,000,000 USDC launch deposit whose shares go to `0xdEaD`.
- `[PASS] test_issue1_capCountsSharesNotUsdc()`: the borrower draws 800,000; a year later the share price is 1.08, and Alice deposits enough to bring total USDC supplied above 5,300,000 while the share supply sits at the cap.
- `[PASS] test_issue1_control_capHoldsAtPriceOne()`: at a price of 1, a deposit past 5,000,000 USDC reverts.
- `[PASS] test_issue2_reserveCheckedBeforeDraw()`: with 5,000,000 USDC of cash, one `borrow(5_000_000e6)` succeeds and leaves 0 cash; Alice cannot redeem even 1% of her shares; only the next `borrow(1)` reverts.

**Your confidence a frontier model fails cold:** medium-high. Two quiet issues and nothing loud; the cap units mistake is the one most likely to be skipped.

### lending-sanctions-escrow
**Instruction:**
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28 and OpenZeppelin 5.4.0. `Market` is a lending market whose ERC20 tokens are lender balances; deposit and withdraw are omitted. A sanctioned lender's tokens must stay in escrow until the lender is cleared or the borrower releases them to the lender early. `sanctions` is a trusted oracle.

```solidity
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISanctions { function isSanctioned(address) external view returns (bool); }

contract Escrow {
    IERC20 public immutable market = IERC20(msg.sender);
    address public immutable borrower;
    address public immutable account;
    ISanctions public immutable sanctions;

    constructor(address b, address a, ISanctions s) { borrower = b; account = a; sanctions = s; }

    function release() external {
        require(msg.sender == borrower || !sanctions.isSanctioned(account), "sanctioned");
        market.transfer(account, market.balanceOf(address(this)));
    }
}

contract Market is ERC20("Market USDC", "mUSDC") {
    address public immutable borrower;
    ISanctions public immutable sanctions;

    constructor(address b, ISanctions s) { borrower = b; sanctions = s; }

    function blockLender(address lender) external {
        require(sanctions.isSanctioned(lender), "not sanctioned");
        _transfer(lender, _escrow(lender, borrower), balanceOf(lender));
    }

    function _escrow(address b, address a) internal returns (address e) {
        bytes memory code = abi.encodePacked(type(Escrow).creationCode, abi.encode(b, a, sanctions));
        e = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(0), keccak256(code))))));
        if (e.codehash == bytes32(0)) new Escrow{salt: 0}(b, a, sanctions);
    }
}
```

List every issue you would report, one line each.

**Answer:** Three issues. (1) `blockLender` calls `_escrow(lender, borrower)`, but `_escrow` takes `(address b, address a)` and builds `Escrow(b, a, ...)` with `b` as the borrower and `a` as the account, so the escrow's account is the real borrower; since the borrower is not sanctioned, anyone can call `release` and the sanctioned lender's tokens go to the borrower. (2) `e.codehash == bytes32(0)` is not a "no contract here" test: an address that holds ETH but no code has codehash `keccak256("")`, so anyone who sends 1 wei to the predicted escrow address makes `_escrow` skip the deployment, and the lender's tokens are moved to an address with no code, where nothing can ever move them (`e.code.length == 0` is the right test). (3) Market tokens move by plain ERC20 transfers that never consult `sanctions`, so a sanctioned lender can move the balance to a fresh address before (or instead of) being blocked, and anyone can send tokens to sanctioned accounts; the escrow then catches nothing.

**Why a model gets it wrong:** Nothing is loud. The swap needs the reader to match two parameter lists that use one-letter names; the codehash test is a well-known idiom that is right for addresses that were never touched; and the free transfers are a missing override, not a line that is wrong. A reviewer who stops at the first finding fails.

**Backing:**
- Issue 1: Code4rena, Wildcat contest, October 2023, H-06, **High**: "Borrower can drain all funds of a sanctioned lender", [finding #68](https://github.com/code-423n4/2023-10-wildcat-findings/issues/68). `_blockAccount()` called `createEscrow(accountAddress, borrower, address(this))` against the signature `createEscrow(borrower, account, asset)`, so the escrow was built with the roles swapped and the borrower could withdraw the lender's balance. Contest finding.
- Issue 2: Code4rena, Wildcat contest, October 2023, H-02, **High**: "`codehash` check in factory contracts does not account for non-empty addresses", [finding #491](https://github.com/code-423n4/2023-10-wildcat-findings/issues/491). `if (escrowContract.codehash != bytes32(0)) return escrowContract;` treated an address holding 1 wei as already deployed, so escrow creation was skipped. Contest finding.
- Issue 3: Code4rena, Wildcat contest, October 2023, H-05, **High**: "Lenders can escape the blacklisting of their accounts because they can move their MarketTokens to different accounts and gain the `WithdrawOnly` Role on any account they want", [finding #266](https://github.com/code-423n4/2023-10-wildcat-findings/issues/266). Wildcat's market tokens could be moved to fresh accounts; the finding's second half, gaining a role through the unprotected `updateLenderAuthorization`, has no counterpart here, only the movement does. Contest finding.

**Spec source:** [EIP-1052](https://eips.ethereum.org/EIPS/eip-1052): `EXTCODEHASH` returns 0 for an account that does not exist and `keccak256("")` (`0xc5d2...a470`) for an account with no code. Solidity docs, [Members of Address Types](https://docs.soliditylang.org/en/v0.8.28/units-and-global-variables.html#members-of-address-types): `<address>.codehash`.

**Grading:** judge: criterion `sanctions_escrow_three_issues`

**Judge criterion:** Passes only if the reply names all three: (1) `blockLender` passes `(lender, borrower)` to `_escrow(b, a)`, so the escrow's borrower and account are swapped and the lender's tokens can be released to the borrower; (2) the `codehash == bytes32(0)` existence check is wrong for an address that already holds ETH, so a 1 wei transfer to the predicted address skips the escrow deployment and the tokens are sent to a codeless address and lost; (3) market-token transfers do not check sanctions, so a sanctioned lender can move tokens to another address and escape the block (or receive them). Fails if any of the three is missing or only hinted at without the mechanism, or if the reply reports as a vulnerability something that is not one here, for example someone deploying different code at the escrow address, `blockLender` being callable by anyone (only sanctioned lenders can be blocked), the borrower's early release paying anyone but the escrow's account, or reentrancy through the market token. A reply that blames `release` being callable by anyone, or the borrower override, for the loss in issue 1 without naming the swapped arguments does not name issue 1. The nit rule above applies.

**Hand cases:**
- pass: "1) blockLender calls _escrow(lender, borrower) while _escrow expects (borrower, account), so the escrow's account is the borrower and anyone can release the lender's tokens to the borrower. 2) The codehash == 0 check fails once someone sends 1 wei to the predicted escrow address (codehash becomes keccak256 of empty), so no escrow is deployed and the tokens are stranded at a codeless address. 3) Market tokens can be transferred freely, so a sanctioned lender moves them to a new address before blockLender."
- pass, different words: "- Argument order bug in the escrow creation: roles reversed, borrower ends up as beneficiary. - Pre-funding the CREATE2 address breaks the deployment check (use code.length), funds burned. - No sanctions hook in _update: sanctioned lenders keep transferring."
- pass, all three plus a nit: "Swapped (b, a) arguments give the lender's escrow to the borrower; codehash check bypassed by 1 wei so tokens go to an empty address; transfers ignore sanctions; also the escrow ignores the transfer return value."
- fail, two of three: "1) The escrow is created with borrower and lender swapped, so the borrower can take the lender's funds. 2) Sanctioned lenders can transfer their market tokens to a fresh address before being blocked."
- fail, all three plus a false claim: "1) Swapped escrow arguments. 2) codehash check skipped after a 1 wei transfer, tokens lost. 3) Transfers ignore sanctions. 4) Anyone can deploy a malicious contract at the escrow address first and receive the tokens."
- fail, hedge: "The escrow arguments look swapped; the codehash check might misbehave for some addresses; transfers may need a sanctions check depending on the omitted code."

**Verified by:** `forge test --offline -vv --root /tmp/subagents/security-quizzes/pilot/multi-opus-lending-sanctions-escrow`. `src/Market.sol` is the snippet byte for byte; the test deploys a subclass that only adds `mint` so lenders hold tokens; the sanctions oracle is a settable mock.
- `[PASS] test_issue1_swappedArgumentsSendLenderFundsToBorrower()`: a sanctioned lender with 1,000 tokens is blocked; the escrow's `account()` is the borrower and `borrower()` is the lender; a stranger calls `release()` and the borrower receives all 1,000.
- `[PASS] test_issue2_oneWeiAtEscrowAddressSkipsDeployment()`: 1 wei is sent to the predicted escrow address, whose codehash becomes `keccak256("")`; `blockLender` deploys nothing and moves the 1,000 tokens there; after the lender is cleared a `release` call reaches no code and the tokens stay stuck.
- `[PASS] test_issue2_control_untouchedAddressDeploys()`: with a fresh address the codehash is zero and the escrow is deployed.
- `[PASS] test_issue3_sanctionedLenderMovesTokensFirst()`: a sanctioned lender transfers its 1,000 tokens to a fresh address; `blockLender` then moves nothing, and the fresh address keeps transferring.

**Your confidence a frontier model fails cold:** high. Three quiet issues; the codehash one in particular is read as a correct idiom by most reviewers.

## Form check and proofs

`python3 -I /tmp/subagents/security-quizzes/check-multi-opus.py` checks every candidate: opener and closing line, under 220 words, 25 to 45 non-blank code lines, no banned or count words in the prose, slug not used before, snippet equal to the project's `src` file, six hand cases with the four required kinds, all fields present. Result: all six pass (214, 190, 217, 193, 218, 215 words; 39, 34, 43, 32, 42, 29 code lines).

All six suites together: `for p in /tmp/subagents/security-quizzes/pilot/multi-opus-*; do forge test --offline --root $p; done` gives 25 passing tests, 0 failing (4, 4, 6, 4, 3, 4).

## Overlaps the owner should know about

- `lending-guard-refund-cap` issue 2 and `fees-keys-subject-and-protocol` issue 2 are both a push payment the receiver can refuse. The victims differ (the protocol's liquidation, the holders' exit).
- `vaults-fee-claim-and-mark` issue 2 and `fees-keys-subject-and-protocol` issue 1 are both a missing access check on fee routing. They are the loud issue in each.
- `lending-pool-cap-and-reserve` has two issues, not three. A third that fit the story (Code4rena Liquid Ron, January 2025, H-01, High, protocol fee still counted in `totalAssets()`, [report](https://code4rena.com/reports/2025-01-liquid-ron)) pushed it past 220 words.

## Rejected on the way

- Flash loan repaid by calling `deposit` inside the callback: the only published backing found was Cyfrin CodeHawks "Thunder Loan", a First Flight training contest, not a firm or live-contest report.
- Liquidation that underflows when collateral is below debt plus bonus: no valid published finding located (the CodeHawks submissions found were judged invalid); the CDP snippet caps the seizure instead.
- Fee or rate change without settling first (Popcorn M-19 #466, Revert Lend M-05 #427): topic already used as `fees-rate-change-reprices-history`.
- Burn amount truncated to `uint96` (PoolTogether H-02 #439): too close to `encoding-downcast-outside-unchecked`.
- Exact-amount repay front-run by a 1-unit repay (Inverse M-05 #252, Revert Lend M-16 #222): griefing only; recorded as a nit in `lending-pool-cap-and-reserve`.
- Anyone closing a fresh position with a zero repay (Revert Lend M-15 #232) and liquidation fee skipped when the collateral is short (Inverse M-06 #275): griefing or small loss, and no room left in a snippet.
- Withdrawal batch joined at its expiry second (Wildcat H-04 #410): needs a batch queue, more than 45 lines.
- Holder-fee offset overwritten without crediting pending fees (Curves M-10 #39): the reward accumulator family is already covered three times in earlier rounds.

Web budget used: 18 of 30 (14 fetches of Code4rena report pages, 5 of them re-reads at an offset, and 4 searches). Finding titles, severities and issue numbers come from the report pages; the GitHub issue bodies themselves were not opened.
