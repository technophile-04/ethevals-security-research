"""Create the six isolated proofs and append candidates with apply_patch."""
from pathlib import Path
import json
import subprocess

ROOT = Path('/tmp/subagents/security-quizzes')

def add(path, content):
    patch = '*** Begin Patch\n*** Add File: ' + str(path) + '\n'
    patch += ''.join('+' + line + '\n' for line in content.splitlines())
    patch += '*** End Patch\n'
    subprocess.run(['apply_patch'], input=patch, text=True, check=True, capture_output=True)

CASES = []

def case(slug, context, code, answer, belief, backing, spec, decoy, criterion, hands, proof, evidence):
    CASES.append(dict(slug=slug, context=context, code=code.strip()+'\n', answer=answer,
        belief=belief, backing=backing, spec=spec, decoy=decoy, criterion=criterion,
        hands=hands, proof=proof, evidence=evidence))

case('vault-liquidity-shortfall-burn',
'''Solidity 0.8.28; cash is an unmodified, non-proxy OpenZeppelin 5.4.0 ERC20. A vault has 100 shares and 100 assets, with 90 assets temporarily locked outside Reserve; redeeming all shares returns 10 assets.''',
'''pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Reserve {
    IERC20 public immutable cash;
    address public immutable vault;
    constructor(IERC20 t) { cash = t; vault = msg.sender; }
    function release(uint n) external returns (uint got) {
        require(msg.sender == vault);
        uint liquid = cash.balanceOf(address(this));
        got = n < liquid ? n : liquid;
        require(cash.transfer(msg.sender, got));
    }
}
contract Vault {
    Reserve public immutable reserve;
    mapping(address => uint) public shares;
    constructor(IERC20 t) { reserve = new Reserve(t); shares[msg.sender] = 100; }
    function redeem(uint n) external {
        require(shares[msg.sender] >= n);
        uint got = reserve.release(n);
        shares[msg.sender] -= n;
        require(reserve.cash().transfer(msg.sender, got));
    }
}''',
'The vault burns all requested shares even when Reserve returns only the liquid portion, so the user loses the claim on the locked assets.',
'An external call before the share update resembles reentrancy, but neither the fixed Reserve nor the pinned ERC20 calls user code.',
'Code4rena, Ethos Reserve Findings & Analysis Report, 2 May 2023, H-02, High, [report](https://code4rena.com/reports/2023-02-ethos#h-02-user-can-lose-up-to-whole-stake-on-vault-withdrawal-when-there-are-funds-locked-in-the-strategy). The finding burns requested shares against a partial strategy withdrawal; no live loss is claimed.',
'The report H-02 describes the difference between requested and returned assets and the missing loss limit; the executable Reserve models temporary illiquidity, with 90 assets outside the liquid reserve.',
'Code4rena Float Capital [invalid finding #57](https://github.com/code-423n4/2021-08-floatcapital-findings/issues/57), 11 August 2021; the sponsor states that payment tokens have no hooks, so reentry is unavailable. The local proof uses that same restriction, rather than assuming every ERC20 is safe.',
'Passes if the reply says requested shares are fully burned when only part of the assets return, destroying the claim on locked assets; fails if it blames reentrancy, hedges between causes, or names a cause absent from the code.',
[
('right','The full share amount is burned for a partial payout, so the remaining locked assets lose their owner claim.'),
('right','redeem reduces shares by n rather than the shares represented by got, even when got is smaller.'),
('right','Temporary strategy illiquidity becomes a permanent user loss because a short withdrawal still consumes the whole claim.'),
('wrong','Either reentrancy before the share update or the partial withdrawal burns the user claim.'),
('wrong','The ERC20 transfer returns false and the vault ignores the failure.'),
('wrong','The external Reserve call precedes the share decrement, allowing recursive redemptions to consume the vault balance.')],
'''contract Token is ERC20 {
    constructor() ERC20("Cash", "C") {}
    function mint(address to, uint n) external { _mint(to,n); }
}
contract Holder {
    Vault public vault;
    uint public callbacks;
    constructor(IERC20 t) { vault = new Vault(t); }
    function run(uint n) external { vault.redeem(n); }
    fallback() external { callbacks++; vault.redeem(1); }
}
contract Proof {
    function testDecoyNoCallbackOrExtraPayout() external {
        Token t = new Token(); Holder h = new Holder(t); Reserve r = h.vault().reserve();
        t.mint(address(r),100); h.run(100);
        require(h.callbacks()==0 && t.balanceOf(address(h))==100, "callback or excess payout");
        require(h.vault().shares(address(h))==0 && t.balanceOf(address(r))==0, "accounting");
    }
    function testRealPartialPayoutDestroysRemainingClaim() external {
        Token t = new Token(); Holder h = new Holder(t); Reserve r = h.vault().reserve();
        t.mint(address(r),10); t.mint(address(0xCAFE),90); h.run(100);
        require(t.balanceOf(address(h))==10 && h.vault().shares(address(h))==0, "loss missing");
        require(t.balanceOf(address(0xCAFE))==90, "locked assets absent");
        (bool ok,) = address(h).call(abi.encodeCall(h.run,(90)));
        require(!ok, "claim survived");
    }
}''',
'The harmless path returns all 100 assets and invokes no receiver callback; the loss path returns 10, burns 100 shares, and rejects the remaining claim.')

case('fees-rate-change-reprices-history',
'''Solidity 0.8.28. A manager changes the daily fee from 1% to 9% after one day, effective from that change onward; collect immediately pays nine assets from a 100-asset vault.''',
'''pragma solidity 0.8.28;
contract Fees {
    address public immutable manager;
    uint public immutable principal;
    uint public rate = 100;
    uint public last;
    constructor() payable {
        manager = msg.sender; principal = msg.value;
        last = block.timestamp;
    }
    function setRate(uint next) external {
        require(msg.sender == manager && next <= 900);
        rate = next;
    }
    function collect() external {
        uint elapsed = block.timestamp - last;
        uint due = principal * rate * elapsed / 10000 / 1 days;
        last = block.timestamp;
        (bool ok,) = manager.call{value: due}("");
        require(ok);
    }
}''',
'setRate replaces the fee rate without settling the elapsed period, so collect charges the new 9% rate for the prior day.',
'The timestamp and an external payment attract familiar warnings, but this loss occurs at the exact intended timestamp and last updates before payment.',
'Code4rena, NOYA Findings & Analysis Report, 17 February 2025, M-53, Medium, [report](https://code4rena.com/reports/2024-04-noya), [finding #544](https://github.com/code-423n4/2024-04-noya-findings/issues/544). A rate update applies new fees to an unsettled past period; no live loss is claimed.',
'Finding #544 shows collectManagementFees using the current managementFee across timePassed and recommends collecting fees before assigning new rates.',
'Code4rena Notional Coop [invalid finding #132](https://github.com/code-423n4/2022-06-notional-coop-findings/issues/132), July 2022, alleges that using block.timestamp for time causes a loss. Here a timestamp measures elapsed time, and no changed timestamp is needed for the overcharge.',
'Passes if the reply says setRate fails to settle accrued fees before changing the rate, so the new rate applies retroactively; fails if it blames timestamp manipulation or reentrancy, hedges between causes, or names a cause absent from the code.',
[
('right','Changing rate without collecting first charges the new percentage for time that elapsed under the old rate.'),
('right','setRate leaves last unchanged, so collect applies 9% to the day that accrued at 1%.'),
('right','The fee period lacks a settlement boundary when its price changes, causing an eight-asset overcharge.'),
('wrong','The loss comes from either a manipulated timestamp or charging the new fee for old time.'),
('wrong','collect can be called twice in the same block to charge the same day twice.'),
('wrong','The contract trusts block.timestamp, so a validator can advance the clock and cause an excessive daily fee.')],
'''contract Proof is Base {
    receive() external payable {}
    function testDecoyExactClockAndRepeatedCollection() external {
        vm.deal(address(this),100 ether); Fees f = new Fees{value:100 ether}();
        vm.warp(block.timestamp+1 days); f.collect(); f.collect();
        require(address(f).balance==99 ether && address(this).balance==1 ether, "clock or repeat loss");
    }
    function testRealNewRateChargesOldDay() external {
        vm.deal(address(this),100 ether); Fees f = new Fees{value:100 ether}();
        vm.warp(block.timestamp+1 days); f.setRate(900); f.collect();
        require(address(f).balance==91 ether && address(this).balance==9 ether, "overcharge missing");
        require(99 ether-address(f).balance==8 ether, "wrong loss");
    }
}''',
'At the exact one-day timestamp, two collections at 1% pay one asset total; changing to 9% before collection pays nine.')

case('vault-aggregate-tick-ownership',
'''Solidity 0.8.28. A manager holds several vaults' pool positions. This vault owns 100 one-wei units backing 100 shares. Another vault adds 200 units at identical ticks; a 100-wei deposit receives 33 shares.''',
'''pragma solidity 0.8.28;
contract Pool {
    mapping(bytes32 => uint) public positions;
    function add(address manager, int24 lo, int24 hi) external payable {
        positions[keccak256(abi.encodePacked(manager, lo, hi))] += msg.value;
    }
}
contract Vault {
    Pool public immutable pool;
    address public immutable manager;
    uint public supply = 100;
    mapping(address => uint) public shares;
    constructor(Pool p, address m) { pool = p; manager = m; shares[msg.sender]=100; }
    function assets() public view returns (uint) {
        bytes32 key = keccak256(abi.encodePacked(manager, int24(-40), int24(40)));
        return pool.positions(key);
    }
    function deposit() external payable {
        uint minted = msg.value * supply / assets();
        shares[msg.sender] += minted; supply += minted;
        pool.add{value: msg.value}(manager, -40, 40);
    }
}''',
'assets attributes the shared manager\'s entire tick-range position to this vault, so unrelated vault liquidity inflates its share price.',
'A packed hash looks collision-prone, but every field has a fixed width; the error concerns ownership of the position behind the key.',
'Code4rena, NOYA Findings & Analysis Report, 17 February 2025, H-20, High, [report](https://code4rena.com/reports/2024-04-noya), [finding #708](https://github.com/code-423n4/2024-04-noya-findings/issues/708). The connector counts all liquidity owned by a shared position manager at the same ticks; no live loss is claimed.',
'Finding #708 identifies pool.positions keyed by positionManager and ticks as aggregate liquidity; a vault must value its own position liquidity.',
'Code4rena Party [invalid, withdrawn finding #12](https://github.com/code-423n4/2023-10-party-findings/issues/12), 26 October 2023, alleges a packed-encoding collision in a signature validator. This adaptation uses only fixed-width fields; the Slither [detector documentation](https://github.com/crytic/slither/wiki/Detector-Documentation#abi-encodepacked-collision) distinguishes ambiguous dynamic arguments.',
'Passes if the reply says assets counts other vaults\' liquidity because the manager-and-ticks key describes an aggregate position rather than this vault\'s own position; fails if it blames a packed-hash collision, hedges between causes, or names a cause absent from the code.',
[
('right','The pool key identifies all liquidity owned by the shared manager at those ticks, so assets includes liquidity belonging to other vaults.'),
('right','Pricing shares from aggregate manager liquidity overvalues this vault and undercredits the new deposit.'),
('right','The ownership boundary is missing from the asset lookup: the shared tick position is larger than this vault\'s claim.'),
('wrong','Either a packed-hash collision or the shared position accounting explains the missing shares.'),
('wrong','The first depositor donates assets until a later deposit rounds down to zero shares.'),
('wrong','abi.encodePacked omits field boundaries, allowing different managers and tick ranges to collide and corrupt the vault price.')],
'''contract Proof is Base {
    function testDecoyFixedWidthEncodingRoundTrips(address m, int24 lo, int24 hi) external pure {
        bytes memory packed = abi.encodePacked(m,lo,hi);
        address recovered; int24 lower; int24 upper;
        assembly {
            recovered := shr(96,mload(add(packed,32)))
            lower := signextend(2,shr(232,mload(add(packed,52))))
            upper := signextend(2,shr(232,mload(add(packed,55))))
        }
        require(packed.length==26 && recovered==m && lower==lo && upper==hi, "ambiguous encoding");
    }
    function testDecoySeparateRangePreservesDepositValue() external {
        vm.deal(address(this),400); Pool p = new Pool(); address m = address(0x1234);
        p.add{value:100}(m,-40,40); p.add{value:200}(m,-41,40);
        Vault v = new Vault(p,m); v.deposit{value:100}();
        require(v.shares(address(this))==100 && v.supply()==200, "unrelated key changed price");
    }
    function testRealForeignLiquidityUndercreditsDepositor() external {
        vm.deal(address(this),400); Pool p = new Pool(); address m = address(0x1234);
        p.add{value:100}(m,-40,40); p.add{value:200}(m,-40,40);
        Vault v = new Vault(p,m); v.deposit{value:100}();
        uint minted = v.shares(address(this));
        require(minted==33 && v.supply()==133, "wrong minted shares");
        uint actualVaultAssets = 200;
        require(minted*actualVaultAssets/v.supply()==49, "economic loss missing");
    }
}''',
'The encoding round-trips over 256 fuzz cases; another tick range leaves a 100-asset deposit worth 100; the same shared range leaves it worth 49.')

case('vault-unstaked-receipt-omitted',
'''Solidity 0.8.28, OpenZeppelin 5.4.0. The initialized proxy holds 101 cash and 100 shares. Booster records 1:1 claims. Investing 100 unstaked lets one cash buy 100 shares.''',
'''pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract Booster {
    mapping(address => uint) public staked; mapping(address => uint) public receipts;
    function credit(address who, uint n, bool stake) external {
        require(msg.sender==who);
        if (stake) staked[who] += n;
        else receipts[who] += n;
    }
}
contract Vault {
    IERC20 public cash; Booster public booster;
    uint public supply = 100; mapping(address => uint) public shares;
    function invest(uint n, bool stake) external {
        SafeERC20.safeTransfer(cash,address(booster),n);
        booster.credit(address(this), n, stake);
    }
    function assets() public view returns (uint) { return cash.balanceOf(address(this)) + booster.staked(address(this)); }
    function deposit(uint n) external {
        uint s = n * supply / assets();
        SafeERC20.safeTransferFrom(cash,msg.sender,address(this),n);
        shares[msg.sender] += s; supply += s;
    }
}''',
'assets omits the unstaked receipt balance, so investing with stake false hides assets that still belong to the vault.',
'Using the non-upgradeable SafeERC20 library in a proxy contract resembles a storage-layout mistake, but the library holds no contract storage.',
'Code4rena, NOYA Findings & Analysis Report, 17 February 2025, M-34, Medium, [report](https://code4rena.com/reports/2024-04-noya), [finding #1110](https://github.com/code-423n4/2024-04-noya-findings/issues/1110). Unstaked Convex deposit tokens disappear from TVL accounting; the finding shows a fall to zero and claims no live loss.',
'Finding #1110 lists totalLpBalanceOf components and omits the receipt-token balance from the stake false branch; Booster models both claims as 1:1 ledger entries.',
'Code4rena Spectra [invalid, withdrawn finding #3](https://github.com/code-423n4/2024-02-spectra-findings/issues/3), February 2024, objects to non-upgradeable SafeERC20 in an upgradeable contract. SafeERC20 5.4.0 is a stateless library; it cannot shift proxy storage.',
'Passes if the reply says assets excludes the receipt balance created when stake is false, understating the vault\'s assets; fails if it blames non-upgradeable SafeERC20, hedges between causes, or names a cause absent from the code.',
[
('right','The unstaked branch creates receipts, but assets counts only cash and staked claims.'),
('right','Receipt tokens from stake false remain owned by the vault but disappear from its asset valuation.'),
('right','The valuation forgets one form of the same investment and sells too many shares to the next depositor.'),
('wrong','The missing receipt balance or the non-upgradeable transfer library causes the valuation loss.'),
('wrong','safeTransfer fails silently and the booster credits unbacked assets.'),
('wrong','The proxy imports non-upgradeable SafeERC20, which writes to the implementation storage instead of the vault and loses the deposited funds.')],
'''contract Token is ERC20 {
    constructor() ERC20("Cash","C") {}
    function mint(address to,uint n) external { _mint(to,n); }
}
contract Proxy {
    address private immutable implementation;
    constructor(address target, address t, address b) {
        implementation = target;
        assembly { sstore(0,t) sstore(1,b) sstore(2,100) }
    }
    fallback() external {
        address target = implementation;
        assembly {
            calldatacopy(0,0,calldatasize())
            let ok := delegatecall(gas(),target,0,calldatasize(),0,0)
            returndatacopy(0,0,returndatasize())
            if iszero(ok) { revert(0,returndatasize()) }
            return(0,returndatasize())
        }
    }
}
contract Proof is Base {
    function deploy() internal returns (Token t, Booster b, Vault v) {
        t = new Token(); b = new Booster(); Vault impl = new Vault();
        v = Vault(address(new Proxy(address(impl),address(t),address(b)))); t.mint(address(v),101);
    }
    function testDecoySafeERC20WorksThroughProxy() external {
        (Token t, Booster b, Vault v) = deploy(); v.invest(100,true);
        require(v.assets()==101 && t.balanceOf(address(b))==100, "transfer or valuation loss");
        require(address(v.cash())==address(t) && address(v.booster())==address(b), "storage changed");
        t.mint(address(this),101); t.approve(address(v),101); v.deposit(101);
        require(v.shares(address(this))==100 && v.supply()==200, "unfair share claim");
    }
    function testRealUnstakedClaimMissingFromValuation() external {
        (Token t, Booster b, Vault v) = deploy(); v.invest(100,false);
        require(v.assets()==1 && b.receipts(address(v))==100, "omission missing");
        require(t.balanceOf(address(b))==100, "assets not backed");
        t.mint(address(this),1); t.approve(address(v),1); v.deposit(1);
        require(v.shares(address(this))==100 && v.supply()==200, "dilution missing");
        require(102*v.shares(address(this))/v.supply()==51, "economic loss missing");
    }
}''',
'The staked branch preserves all 101 reported assets through the proxy; the unstaked branch lets a one-asset deposit buy a 51-asset claim, diluting existing shares by 50 assets.')

case('lending-ratio-decimal-mismatch',
'''Solidity 0.8.28. A manager must maintain a 180% collateral ratio; the lender liquidates below 120%. logo is display metadata. Reducing 200 collateral to 110 against 100 debt passes adjust and causes a five-unit liquidation penalty.''',
'''pragma solidity 0.8.28;
contract Position {
    address public immutable manager;
    address public logo;
    uint public collateral = 200;
    uint public debt = 100;
    uint public minimum = 1.8e18;
    constructor(address image) { manager = msg.sender; logo = image; }
    function nominalRatio() public view returns (uint) {
        return collateral * 1e20 / debt;
    }
    function adjust(uint take) external {
        require(msg.sender == manager && take <= collateral);
        collateral -= take;
        require(nominalRatio() >= minimum);
    }
    function liquidate() external {
        require(collateral * 100 < debt * 120);
        collateral -= debt + 5;
        debt = 0;
    }
}''',
'adjust compares a ratio scaled by 1e20 with a minimum scaled by 1e18, admitting a position below the intended collateral ratio.',
'A constructor accepts a zero address, but it stores display metadata that never authorizes an action or receives funds.',
'Code4rena, NOYA Findings & Analysis Report, 17 February 2025, M-47, Medium, [report](https://code4rena.com/reports/2024-04-noya), [finding #759](https://github.com/code-423n4/2024-04-noya-findings/issues/759). Prisma exposes a 20-decimal nominal ratio while the connector compares an 18-decimal minimum; the finding describes unintended liquidation risk, not a live loss.',
'[PrismaMath at 63f3d08](https://github.com/prisma-fi/prisma-contracts/blob/63f3d08d6d7ae9fc74855a489eeae080b72a3f46/contracts/dependencies/PrismaMath.sol#L17) defines the 1e20 precision; finding #759 names the comparison and the division by 100 required to match the connector scale.',
'Code4rena Meebits [invalid finding #6](https://github.com/code-423n4/2021-04-meebits-findings/issues/6), 18 April 2021, alleges harm from missing constructor zero-address validation. The local version stores an address that no financial path reads; its safety follows from that narrower role, not from the label alone.',
'Passes if the reply says nominalRatio uses 1e20 while minimum uses 1e18, so adjust admits insufficient collateral; fails if it blames the zero logo address, hedges between causes, or names a cause absent from the code.',
[
('right','The 20-decimal nominal ratio is compared with an 18-decimal threshold, so the collateral check is 100 times too weak.'),
('right','adjust fails to normalize nominalRatio to the scale of minimum and therefore accepts the 110% position.'),
('right','The health requirement and the reported ratio use different units, so the apparent safety check admits a liquidatable position.'),
('wrong','Either accepting a zero logo or the ratio scale mismatch exposes the position to loss.'),
('wrong','The checked subtraction underflows and wraps collateral to a large value.'),
('wrong','The constructor omits a zero-address check for logo, so liquidation sends the user collateral to the zero address.')],
'''contract Proof {
    function testDecoyZeroLogoDoesNotAffectSafePosition() external {
        Position z = new Position(address(0)); Position n = new Position(address(1));
        z.adjust(10); n.adjust(10);
        require(z.collateral()==190 && z.collateral()==n.collateral(), "logo changed assets");
        (bool ok,) = address(z).call(abi.encodeCall(z.liquidate,()));
        require(!ok && z.collateral()==190, "safe collateral lost");
    }
    function testRealWrongScaleAdmitsLiquidationPenalty() external {
        Position p = new Position(address(1)); p.adjust(90);
        require(p.nominalRatio()==1.1e20 && p.nominalRatio()/100<p.minimum(), "bad state not admitted");
        p.liquidate();
        require(p.collateral()==5 && p.debt()==0, "penalty missing");
        require(200-(90+p.collateral())-100==5, "wrong net loss");
    }
}''',
'Zero and nonzero logo addresses preserve equal collateral and reject liquidation at 190%; the wrong-scale check admits 110% and liquidation consumes an extra five units.')

case('vault-underlying-rate-applied-twice',
'''Solidity 0.8.28. Receipt credits wei 1:1. The vault's 100 shares own 100 LP units worth two wei each; lpToAsset quotes underlying assets. Depositing 100 wei returns 25 shares.''',
'''pragma solidity 0.8.28;
contract Receipt {
    mapping(address => uint) public balance;
    function deposit() external payable { balance[msg.sender] += msg.value; }
}
contract Vault {
    Receipt public immutable receipt = new Receipt();
    uint public lp = 100;
    uint public lpToAsset = 2e18;
    uint public receiptToAsset = 2e18;
    uint public supply = 100;
    mapping(address => uint) public shares;
    function assets() public view returns (uint) {
        return lp * lpToAsset / 1e18 * receiptToAsset / 1e18;
    }
    function deposit() external payable {
        uint beforeBalance = receipt.balance(address(this));
        address(receipt).call{value: msg.value}(abi.encodeCall(Receipt.deposit, ()));
        require(receipt.balance(address(this)) - beforeBalance == msg.value);
        uint n = msg.value * supply / assets();
        shares[msg.sender] += n; supply += n;
    }
}''',
'assets multiplies an LP-to-underlying quote by the receipt-to-underlying rate again, doubling the valuation and giving the depositor too few shares.',
'The ignored call result resembles a lost-funds bug, but the fixed callee credits exactly msg.value and the balance-delta requirement rejects any short credit.',
'Code4rena, NOYA Findings & Analysis Report, 17 February 2025, H-22, High, [report](https://code4rena.com/reports/2024-04-noya), [finding #350](https://github.com/code-423n4/2024-04-noya-findings/issues/350). The connector treats getLpToAssetRate as an LP-to-SY quote, then converts an already underlying-denominated value again; no live loss is claimed.',
'Finding #350 quotes the LP-to-asset rate definition and identifies adding it to SYAmount as the unit error. This model uses equal 2e18 rates to show the duplicate conversion.',
'Code4rena Badger [invalid, withdrawn finding #16](https://github.com/code-423n4/2024-06-badger-validation/issues/16), June 2024, alleges loss because a raw deposit call ignores success while accounting from a token balance delta. The local version adds an exact-delta requirement and fixes the callee in code; no claim rests on the withdrawn finding alone.',
'Passes if the reply says assets applies receiptToAsset to an LP value already quoted in underlying assets, counting that conversion twice and undercrediting deposits; fails if it blames the ignored call result, hedges between causes, or names a cause absent from the code.',
[
('right','assets converts an LP-to-underlying quote through receiptToAsset a second time, inflating the price used to mint shares.'),
('right','The LP rate already returns assets, so multiplying by the receipt exchange rate again doubles reported value and halves the new shares.'),
('right','The valuation confuses an underlying-denominated amount with receipt units and applies the same unit conversion twice.'),
('wrong','Either ignoring the low-level success flag or applying the receipt rate twice explains the loss.'),
('wrong','The share calculation includes the incoming deposit in its denominator before minting.'),
('wrong','The low-level call discards its success flag, so failed deposits consume ETH without creating receipt balances and cause the missing shares.')],
'''contract RejectDeposit {
    function balance(address) external pure returns(uint) { return 0; }
    function deposit() external payable { revert(); }
}
contract Proof is Base {
    function testDecoyCallCreditsExactlyAndFailureRollsBack() external {
        vm.deal(address(this),100); Vault v = new Vault();
        vm.store(address(v),bytes32(uint(2)),bytes32(uint(1e18))); v.deposit{value:100}();
        require(v.receipt().balance(address(v))==100 && address(v.receipt()).balance==100, "deposit lost");
        require(v.shares(address(this))==50 && 300*50/v.supply()==100, "control lost value");
        uint supplyBefore = v.supply();
        vm.etch(address(v.receipt()),address(new RejectDeposit()).code);
        vm.deal(address(this),100);
        (bool ok,) = address(v).call{value:100}(abi.encodeCall(v.deposit,()));
        require(!ok && address(this).balance==100 && v.supply()==supplyBefore, "failure retained funds");
    }
    function testRealDuplicateConversionUndercreditsDepositor() external {
        vm.deal(address(this),100); Vault v = new Vault();
        require(v.assets()==400, "bad valuation missing"); v.deposit{value:100}();
        require(v.shares(address(this))==25 && v.supply()==125, "wrong minted shares");
        uint actualAssets = 200 + v.receipt().balance(address(v));
        require(v.shares(address(this))*actualAssets/v.supply()==60, "economic loss missing");
    }
}''',
'The fixed callee receives and credits all 100 wei; a reverting callee rolls back the payment and shares; the wrong valuation leaves the 100-wei depositor with a 60-wei claim.')

BASE = '''pragma solidity 0.8.28;
interface Vm {
    function deal(address,uint) external;
    function warp(uint) external;
    function etch(address,bytes calldata) external;
    function store(address,bytes32,bytes32) external;
}
contract Base {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
}
'''
add(ROOT/'pilot/_decoy/Base.sol', BASE)
add(ROOT/'pilot-decoy.md', '''# Root-cause candidates with harmless security smells

Six candidates follow brief5.md. All files and proof projects live under `/tmp/subagents/security-quizzes/`.
The repository stayed read only. No model trials or judge calls ran.

ADR 0016 accepts correct paraphrases and rejects contradictory causes or hedges.
The named `agent-registries` folder uses a fixed-answer check and has no hand cases.
I also read `wallet-atomic-ready/tests/` for the existing judge format.

Sources use 38 searches or fetches, including one failed rate-limited request, within the limit of 40.
The snippets adapt published findings; they do not reproduce full deployed protocols.
The proofs import each question's exact Solidity file and pin Solidity 0.8.28 with Cancun rules.
The token dependency is the existing local OpenZeppelin package at version 5.4.0.
No source request downloaded proof dependencies.
''')
for c in CASES:
    folder = ROOT/'pilot'/c['slug']
    add(folder/'foundry.toml', '''[profile.default]
src = "src"
test = "test"
solc = "0.8.28"
evm_version = "cancun"
optimizer = true
optimizer_runs = 200
allow_paths = [".."]
remappings = ["@openzeppelin/contracts/=../deps/oz5/", "decoy/=../_decoy/"]
[fuzz]
runs = 256
''')
    add(folder/'src/Model.sol', c['code'])
    imports = '''pragma solidity 0.8.28;
import "../src/Model.sol";
import "decoy/Base.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
'''
    add(folder/'test/Proof.t.sol', imports+c['proof']+'\n')
    instruction = 'You are an expert security researcher and smart contract auditor.\n\n'+c['context']+'\n\n```solidity\n'+c['code']+'```\n\nWhat is the root cause of the loss? Answer in one sentence.'
    add(folder/'instruction.md',instruction+'\n')
    add(folder/'hand-cases.json',json.dumps({'cases':[dict(want=w,reply=r) for w,r in c['hands']]},indent=2)+'\n')
    section = '\n### '+c['slug']+'\n**Instruction:**\n'+instruction+'\n\n'
    section += '**Answer:** '+c['answer']+'\n\n**Why a model gets it wrong:** '+c['belief']+'\n\n'
    section += '**Backing:** '+c['backing']+'\n\n**Spec source:** '+c['spec']+'\n\n'
    section += '**Decoy source and scope:** '+c['decoy']+'\n\n'
    section += '**Grading:** judge: the binary criterion below.\n\n**Judge criterion:** '+c['criterion']+'\n\n'
    section += '**Hand cases:**\n'+''.join(str(i+1)+'. '+('Pass' if w=='right' else 'Fail')+': '+r+'\n' for i,(w,r) in enumerate(c['hands']))
    section += '\n**Your confidence a frontier model fails cold:** '+('medium' if c['slug'] in ['vault-liquidity-shortfall-burn','vault-aggregate-tick-ownership','vault-underlying-rate-applied-twice'] else 'low')+'. This is a prediction; no cold trial has run.\n\n'
    section += '**Verified by:** pending Foundry run at `'+str(folder)+'`. '+c['evidence']+'\n'
    current = (ROOT/'pilot-decoy.md').read_text()
    last = current.splitlines()[-1]
    patch = '*** Begin Patch\n*** Update File: '+str(ROOT/'pilot-decoy.md')+'\n@@\n '+last+'\n'
    patch += ''.join('+'+line+'\n' for line in section.splitlines())+'*** End Patch\n'
    subprocess.run(['apply_patch'],input=patch,text=True,check=True,capture_output=True)

print(json.dumps([{'slug':c['slug'],'lines':len(c['code'].splitlines()),'words':len(('You are an expert security researcher and smart contract auditor. '+c['context']+' '+c['code']+' What is the root cause of the loss? Answer in one sentence.').split())} for c in CASES],indent=2))
