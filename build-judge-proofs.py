"""Build reduced proofs from the exact instruction snippets, using apply_patch."""
from pathlib import Path
import re
import subprocess

ROOT = Path('/tmp/subagents/security-quizzes')
document = (ROOT / 'pilot-judge.md').read_text()
snippets = {
    slug: re.search(r'```solidity\n(.*?)\n```', body, re.S).group(1)
    for slug, body in re.findall(r'^### (\S+)\n(.*?)(?=^### |^## Rejected|\Z)', document, re.S | re.M)
}
CONFIG = '''[profile.default]
src = "src"
test = "test"
solc = "0.8.28"
evm_version = "cancun"
optimizer = true
optimizer_runs = 200
via_ir = false
'''
fixtures = {}

fixtures['options-position-fingerprint-wrap'] = ('''
contract Model {
    mapping(uint256 => int256) public margin;
    bytes32 public stored;
    constructor() {
        margin[7] = 10; margin[19] = -20;
        stored = bytes32((uint256(2) << 248)
            | uint248(uint256(keccak256(abi.encode(uint256(7)))))
            ^ uint248(uint256(keccak256(abi.encode(uint256(19))))));
    }
''', '''
}
contract Proof {
    function positions(uint256 extra) internal pure returns (uint256[] memory ids) {
        ids = new uint256[](2 + extra); ids[0] = 7; ids[1] = 19;
        for (uint256 i = 2; i < ids.length; ++i) ids[i] = 7;
    }
    function testActualPositionsAreInsolvent() external {
        Model m = new Model(); require(!m.healthy(positions(0)), "actual list healthy");
    }
    function test256CopiesPreserveCommitmentAndInflateMargin() external {
        Model m = new Model(); require(m.healthy(positions(256)), "duplicates rejected");
    }
    function testTwoCopiesFailCountCheck() external {
        Model m = new Model();
        (bool ok,) = address(m).call(abi.encodeCall(m.healthy, (positions(2))));
        require(!ok, "count did not distinguish two extra entries");
    }
}
''')

fixtures['lending-repayment-borrower-changes'] = ('''
contract Cash {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 n) external { balanceOf[to] += n; }
    function approve(address spender, uint256 n) external { allowance[msg.sender][spender] = n; }
    function transferFrom(address from, address to, uint256 n) external returns (bool) {
        allowance[from][msg.sender] -= n; balanceOf[from] -= n; balanceOf[to] += n;
        return true;
    }
}
contract Model {
    Cash public cash;
    address public keeper;
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    modifier onlyKeeper() { require(msg.sender == keeper); _; }
    constructor() {
        keeper = msg.sender; cash = new Cash();
        loans[41] = Loan(msg.sender, 100, false);
        collateral[msg.sender] = 150; debt[msg.sender] = 100;
        cash.mint(msg.sender, 100);
    }
    function _liquidate(address who, uint256 due) internal {
        collateral[who] -= due + 5; debt[who] -= due;
    }
    function _fund(address who) internal { cash.mint(who, 90); debt[who] += 100; }
    function _closeDebt(address who, uint256 due) internal { debt[who] -= due; }
''', '''
}
contract Proof {
    function testReplacementThenPendingRepaymentChargesOldBorrowerTwice() external {
        Model m = new Model(); Cash cash = m.cash();
        cash.approve(address(m), 100);
        address next = address(0xBEEF); m.replace(41, next); m.repay(41);
        require(m.collateral(address(this)) == 45, "liquidation not charged");
        require(cash.balanceOf(address(this)) == 0, "old borrower cash not charged");
        require(cash.balanceOf(next) == 90 && m.debt(next) == 0, "successor did not benefit");
    }
    function testRepayBeforeReplacementPaysOriginalDebt() external {
        Model m = new Model(); m.cash().approve(address(m), 100); m.repay(41);
        require(m.collateral(address(this)) == 150, "collateral charged");
        require(m.debt(address(this)) == 0, "original debt remains");
    }
}
''')

fixtures['bridge-holder-flag-freezes-local-balance'] = ('''
contract Model {
    mapping(address => uint256) public balanceOf;
    bool public locked = true;
    address public staking = address(0x777);
    address public bridge;
    error Restricted();
    modifier onlyBridge() { require(msg.sender == bridge); _; }
    constructor() { bridge = msg.sender; balanceOf[msg.sender] = 1000; }
    function _mint(address to, uint256 n) internal { balanceOf[to] += n; }
    function _transfer(address from, address to, uint256 n) internal {
        balanceOf[from] -= n; balanceOf[to] += n;
    }
''', '''
}
contract Proof {
    function testUnsolicitedCreditRestrictsLocalBalance() external {
        Model m = new Model(); m.credit(address(this), 1);
        (bool ok,) = address(m).call(abi.encodeCall(m.transfer, (address(0xAAA), 1000)));
        require(!ok && m.balanceOf(address(this)) == 1001, "local balance still transferable");
    }
    function testLocalBalanceTransfersBeforeCredit() external {
        Model m = new Model(); require(m.transfer(address(0xAAA), 1000));
        require(m.balanceOf(address(0xAAA)) == 1000, "local transfer absent");
    }
    function testSendingImportedAmountToStakingDoesNotClearFlag() external {
        Model m = new Model(); m.credit(address(this), 1); m.transfer(m.staking(), 1);
        require(m.balanceOf(address(this)) == 1000 && m.imported(address(this)));
        (bool ok,) = address(m).call(abi.encodeCall(m.transfer, (address(0xAAA), 1000)));
        require(!ok, "flag cleared");
    }
}
''')

fixtures['emissions-burned-principal-subtracted-twice'] = ('''
contract TokenStats {
    uint256 public totalSupply;
    uint256 private escrow;
    constructor(uint256 s, uint256 e) { totalSupply = s; escrow = e; }
    function balanceOf(address) external view returns (uint256) { return escrow; }
}
contract LockStats {
    uint256 public burnedPrincipal;
    constructor(uint256 retired) { burnedPrincipal = retired; }
    function bonus(uint256) external pure returns (uint256) { return 0; }
}
contract Model {
    TokenStats public token;
    LockStats public locks;
    address public locker = address(0x777);
    constructor(uint256 retired) { token = new TokenStats(900, 100); locks = new LockStats(retired); }
''', '''
}
contract Proof {
    function testBurnedPrincipalUnderpaysWithoutRounding() external {
        Model m = new Model(200);
        require(m.rebase(16200) == 3600, "unexpected rebase");
        uint256 correct = (uint256(16200) * 800 / 900) * 800 / (2 * 900);
        require(correct == 6400 && m.rebase(16200) < correct, "underpayment absent");
        require(16200 * 600 % 900 == 0 && 10800 * 600 % 1800 == 0, "division loses precision");
    }
    function testNoBurnedPrincipalMatchesCirculatingSupply() external {
        Model m = new Model(0); require(m.rebase(16200) == 6400, "control differs");
    }
}
''')

fixtures['tokens-whitelisted-burn-short-circuit'] = ('''
contract Model {
    mapping(address => bool) public minter;
    mapping(address => bool) public blocked;
    mapping(address => bool) public listed;
    mapping(address => uint256) public balanceOf;
    constructor(bool isListed, bool isBlocked) {
        listed[msg.sender] = isListed; blocked[msg.sender] = isBlocked;
        listed[address(0xAAA)] = true; balanceOf[msg.sender] = 100;
    }
    function _burn(address from, uint256 n) internal { balanceOf[from] -= n; }
    function transfer(address to, uint256 n) external {
        require(permitted(msg.sender, to)); balanceOf[msg.sender] -= n; balanceOf[to] += n;
    }
''', '''
}
contract Proof {
    function testListedBlockedHolderBurnsEntireRecoverableBalance() external {
        Model m = new Model(true, true); m.burn(100);
        require(m.balanceOf(address(this)) == 0, "recoverable balance survives");
    }
    function testUnlistedBlockedHolderCannotBurn() external {
        Model m = new Model(false, true);
        (bool ok,) = address(m).call(abi.encodeCall(m.burn, (100)));
        require(!ok && m.balanceOf(address(this)) == 100, "unlisted holder burns");
    }
    function testListedUnblockedHolderCanBurn() external {
        Model m = new Model(true, false); m.burn(100);
        require(m.balanceOf(address(this)) == 0, "intended burn fails");
    }
    function testBlockedHolderCannotTransferNormally() external {
        Model m = new Model(true, true);
        (bool ok,) = address(m).call(abi.encodeCall(m.transfer, (address(0xAAA), 100)));
        require(!ok && m.balanceOf(address(this)) == 100, "normal transfer ignores blocking");
    }
}
''')

fixtures['swaps-direction-ignores-pool-token-order'] = ('''
contract Pool {
    address public token0;
    address public token1;
    constructor(address a, address b) { (token0, token1) = a < b ? (a, b) : (b, a); }
}
contract Quoter {
    function quote(address p, address input, address output, uint256 amount) external view returns (uint256) {
        Pool pool = Pool(p);
        require((input == pool.token0() && output == pool.token1())
            || (input == pool.token1() && output == pool.token0()));
        return amount;
    }
}
contract Router {
    function inputOf(uint256 descriptor) external view returns (address) {
        Pool p = Pool(address(uint160(descriptor)));
        return descriptor >> 255 == 1 ? p.token1() : p.token0();
    }
}
contract Model {
    address public wrapped;
    address public pool;
    Quoter public quoter;
    constructor(address w, address other) { wrapped = w; pool = address(new Pool(w, other)); quoter = new Quoter(); }
''', '''
}
contract Proof {
    function testWrappedAsToken0QuotesCorrectlyButEncodesWrongInput() external {
        Model m = new Model(address(0x100), address(0x200)); Router router = new Router();
        (uint256 descriptor, uint256 expected) = m.route(address(0x100), address(0x200), 80);
        require(expected == 80, "quote wrong");
        require(address(uint160(descriptor)) == m.pool(), "pool address overwritten");
        require(router.inputOf(descriptor) == address(0x200), "unexpected input direction");
    }
    function testWrappedAsToken1MatchesInput() external {
        Model m = new Model(address(0x300), address(0x200)); Router router = new Router();
        (uint256 descriptor,) = m.route(address(0x300), address(0x200), 80);
        require(router.inputOf(descriptor) == address(0x300), "control input wrong");
    }
    function testOtherInputAlsoReversesForWrappedAsToken0() external {
        Model m = new Model(address(0x100), address(0x200)); Router router = new Router();
        (uint256 descriptor,) = m.route(address(0x200), address(0x100), 80);
        require(router.inputOf(descriptor) == address(0x100), "reverse route unexpectedly correct");
    }
}
''')

patch = ['*** Begin Patch']
for slug, snippet in snippets.items():
    before, after = fixtures[slug]
    contents = {
        'foundry.toml': CONFIG,
        'test/Proof.t.sol': '// SPDX-License-Identifier: MIT\npragma solidity 0.8.28;\n' + before + snippet + after,
    }
    for relative, content in contents.items():
        path = ROOT / 'pilot' / slug / relative
        if path.exists():
            patch.append(f'*** Delete File: {path}')
        patch.append(f'*** Add File: {path}')
        patch.extend('+' + line for line in content.splitlines())
patch.append('*** End Patch')
subprocess.run(['apply_patch', '\n'.join(patch) + '\n'], check=True)
