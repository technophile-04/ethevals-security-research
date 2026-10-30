// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Base,Token} from "common/Support.sol";
contract Payer {
    address public immutable rewards;
    Token public immutable token;
    constructor(Token t) {rewards=msg.sender;token=t;}
    function pay(address to,uint256 a) external {
        require(msg.sender==rewards);
        require(token.transferFrom(rewards,to,a));
    }
}
contract Rewards {
    Token public immutable token;
    Token public immutable shares;
    Payer public immutable payer;
    uint256 public index=1e18;
    mapping(address=>uint256) public paid;
    constructor(Token t,Token s) {token=t;shares=s;payer=new Payer(t);}
    function claim() external {
        uint256 a=shares.balanceOf(msg.sender)
            *(index-paid[msg.sender])/1e18;
        paid[msg.sender]=index;
        token.approve(address(payer),a);
        payer.pay(msg.sender,a);
    }
    function earned(address who) external view returns (uint256) {
        return shares.balanceOf(who)*(index-paid[who])/1e18;
    }
}
contract Proof is Base {
    function setup() internal returns(Token t,Token s,Rewards r) {
        t=new Token();s=new Token();r=new Rewards(t,s);
        s.mint(ALICE,100);s.mint(CAROL,200);t.mint(address(r),300);
    }
    function testDecoyIgnoredApprovalCannotMisfundClaim() external {
        (Token t,,Rewards r)=setup();
        vm.prank(ALICE);r.claim();
        require(t.balanceOf(ALICE)==100 && t.balanceOf(address(r))==200,"first payout mismatch");
        require(t.allowance(address(r),address(r.payer()))==0,"unused approval remains");
        vm.prank(ALICE);r.claim();
        require(t.balanceOf(ALICE)==100 && t.balanceOf(address(r))==200,"duplicate payout without transfer");
        vm.prank(CAROL);r.claim();
        require(t.balanceOf(CAROL)==200 && t.balanceOf(address(r))==0,"normal claims lost value");
    }
    function testRealTransferPaysHistoricalRewardsTwice() external {
        (Token t,Token s,Rewards r)=setup();
        vm.prank(ALICE);r.claim();
        vm.prank(ALICE);s.transfer(BOB,100);
        require(r.earned(BOB)==100,"checkpoint moved with shares");
        vm.prank(BOB);r.claim();
        require(t.balanceOf(BOB)==100 && t.balanceOf(address(r))==100,"no repeated historical payout");
        vm.prank(CAROL);(bool ok,)=address(r).call(abi.encodeCall(r.claim,()));
        require(!ok && r.earned(CAROL)==200 && t.balanceOf(CAROL)==0,"other holder not shortchanged");
    }
}
