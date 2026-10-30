// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Base,Token} from "common/Support.sol";
import {ECDSA} from "oz/utils/cryptography/ECDSA.sol";
contract Rewards {
    address public immutable router;
    Token public immutable token;
    mapping(address=>uint256) public credit;
    constructor(Token t) {router=msg.sender;token=t;}
    function pay(address member,address referral) external {
        require(msg.sender==router);
        credit[member]+=9;
        credit[referral]+=1;
    }
    function withdraw() external {
        uint256 a=credit[msg.sender];
        credit[msg.sender]=0;
        require(token.transfer(msg.sender,a));
    }
}
contract Router {
    address public immutable signer;
    Rewards public immutable rewards;
    mapping(bytes32=>bool) public used;
    constructor(Token t,address s) { signer=s; rewards=new Rewards(t); }
    function claim(address member,address referral,uint256 n,
        bytes calldata memo,bytes calldata sig) external {
        bytes32 h=keccak256(abi.encodePacked(
            block.chainid,address(this),member,n,memo));
        require(ECDSA.recover(h,sig)==signer);
        require(!used[h]);
        used[h]=true;
        rewards.pay(member,referral);
    }
}
contract Proof is Base {
    uint256 constant KEY=0xA57AA;
    function signature(Router r,address member,uint256 n,bytes memory memo) internal returns(bytes memory) {
        bytes32 h=keccak256(abi.encodePacked(block.chainid,address(r),member,n,memo));
        (uint8 v,bytes32 rr,bytes32 s)=vm.sign(KEY,h); return abi.encodePacked(rr,s,v);
    }
    function setup() internal returns(Token t,Router r) {
        t=new Token(); r=new Router(t,vm.addr(KEY)); t.mint(address(r.rewards()),100);
    }
    function testDecoyPackedFieldsCannotBeResplit() external {
        (Token t,Router r)=setup(); bytes memory sig=signature(r,ALICE,7,hex"1234");
        (bool ok,)=address(r).call(abi.encodeCall(r.claim,(BOB,CAROL,7,hex"1234",sig)));
        require(!ok,"changed member accepted");
        (ok,)=address(r).call(abi.encodeCall(r.claim,(ALICE,CAROL,7,hex"123400",sig)));
        require(!ok && t.balanceOf(address(r.rewards()))==100 && r.rewards().credit(CAROL)==0,"changed memo lost funds");
        r.claim(ALICE,CAROL,7,hex"1234",sig);
        require(r.rewards().credit(ALICE)==9 && r.rewards().credit(CAROL)==1,"control signature failed");
    }
    function testFuzzPackedEncodingHasUniqueFieldBoundaries(address member,uint256 n,bytes calldata memo) external pure {
        bytes memory packed=abi.encodePacked(uint256(1),address(0x123),member,n,memo);
        address gotMember; uint256 gotN;
        assembly {gotMember:=shr(96,mload(add(packed,84))) gotN:=mload(add(packed,104))}
        require(gotMember==member && gotN==n && packed.length==104+memo.length,"fixed boundary changed");
        for(uint256 i;i<memo.length;++i) require(packed[104+i]==memo[i],"memo boundary changed");
    }
    function testRealUnsignedReferralReceivesMoney() external {
        (Token t,Router r)=setup(); bytes memory sig=signature(r,ALICE,7,hex"1234");
        vm.prank(BOB); r.claim(ALICE,BOB,7,hex"1234",sig);
        Rewards rewards=r.rewards();
        vm.prank(BOB); rewards.withdraw();
        require(t.balanceOf(BOB)==1 && r.rewards().credit(CAROL)==0,"referral not redirected");
        require(t.balanceOf(address(r.rewards()))==99 && r.rewards().credit(ALICE)==9,"payout accounting mismatch");
        (bool ok,)=address(r).call(abi.encodeCall(r.claim,(ALICE,BOB,7,hex"1234",sig)));
        require(!ok,"unrelated same-message replay");
    }
}
