// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract Payout {
 address public owner; uint256 public paid;
 constructor(){owner=address(0xA11CE);}
 function withdraw() external {
  assembly {
   function checkOwner() -> r { if iszero(eq(caller(),sload(0))) {revert(0,0)} r:=1 }
   function finish() -> r {sstore(1,1) return(0,0)}
   function combine(a,b) -> r {r:=add(a,b)}
   pop(combine(finish(),checkOwner()))
  }
 }
}
contract Proof {
 function testCustomInlinerPaysBeforeAuthorization() public {
  Payout p=new Payout();
  (bool ok,)=address(p).call(abi.encodeCall(p.withdraw,()));
  require(ok&&p.paid()==1,"authorization ran first");
 }
}

