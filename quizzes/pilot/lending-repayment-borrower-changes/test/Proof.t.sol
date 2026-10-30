// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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
struct Loan { address borrower; uint256 due; bool paid; }
mapping(uint256 => Loan) public loans;
function replace(uint256 id, address next) external onlyKeeper {
    _liquidate(loans[id].borrower, loans[id].due);
    loans[id].borrower = next;
    _fund(next);
}
function repay(uint256 id) external {
    Loan storage loan = loans[id];
    require(!loan.paid);
    cash.transferFrom(msg.sender, address(this), loan.due);
    _closeDebt(loan.borrower, loan.due);
    loan.paid = true;
}
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
