// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Base,Token} from "common/Support.sol";
contract Loan {
    Token public immutable token;
    address public immutable lender;
    mapping(address=>uint256) public principal;
    mapping(address=>uint256) public interest;
    mapping(address=>uint256) public last;
    constructor(Token t,address borrower,address funder) {
        token=t;lender=funder;principal[borrower]=365000;last[borrower]=block.timestamp;
    }
    function repay(uint256 a) public {
        require(token.transferFrom(msg.sender,lender,a));
        require(a>0 && a<=principal[msg.sender]);
        uint256 d=(block.timestamp-last[msg.sender])/1 days;
        interest[msg.sender]+=principal[msg.sender]*d/365;
        last[msg.sender]=block.timestamp;
        principal[msg.sender]-=a;
    }
    function close() external {
        repay(principal[msg.sender]);
        uint256 fee=interest[msg.sender];
        interest[msg.sender]=0;
        require(token.transferFrom(msg.sender,lender,fee));
    }
}
contract Proof is Base {
    function setup() internal returns(Token t,Loan loan) {
        vm.warp(10 days);t=new Token();loan=new Loan(t,ALICE,CAROL);
        t.mint(ALICE,400000);vm.prank(ALICE);t.approve(address(loan),400000);
    }
    function testDecoyLateRequireRollsBackCompletedTokenTransfer() external {
        (Token t,Loan loan)=setup();
        vm.prank(ALICE);(bool ok,)=address(loan).call(abi.encodeCall(loan.repay,(365001)));
        require(!ok && t.balanceOf(ALICE)==400000 && t.balanceOf(CAROL)==0,"late revert lost tokens");
        require(t.allowance(ALICE,address(loan))==400000 && loan.principal(ALICE)==365000,"late revert left state");
        require(loan.last(ALICE)==10 days && loan.interest(ALICE)==0,"late revert accrued interest");
    }
    function testRealFractionalDaysDisappearFromFinalPayment() external {
        (Token t,Loan loan)=setup();
        vm.warp(10 days+36 hours);vm.prank(ALICE);loan.repay(1);
        vm.warp(13 days);vm.prank(ALICE);loan.close();
        uint256 expectedInterest=uint256(365000)*36 hours/365 days+uint256(364999)*36 hours/365 days;
        require(expectedInterest==2999,"reference accrual changed");
        require(t.balanceOf(CAROL)==366999 && 365000+expectedInterest-t.balanceOf(CAROL)==1000,"no realized interest loss");
        require(loan.principal(ALICE)==0 && loan.interest(ALICE)==0,"loan not closed");
    }
    function testControlWholeDaysPayFullElapsedInterest() external {
        (Token t,Loan loan)=setup();
        vm.warp(13 days);vm.prank(ALICE);loan.close();
        require(t.balanceOf(CAROL)==368000,"whole-day control underpaid");
    }
}
