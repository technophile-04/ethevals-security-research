// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "oz/utils/cryptography/MerkleProof.sol";
contract Distributor {
 bytes32 public immutable root; bool public claimed;
 constructor(bytes32 r) {root=r;}
 function claim(bytes32 a,bytes32 b,bytes32[] memory proof) external {
  bytes32 leaf=keccak256(bytes.concat(keccak256(abi.encode(a,b))));
  require(MerkleProof.verify(proof,root,leaf),"proof"); claimed=true;
 }
}
contract Proof {
 function testInternalNodeCannotBecomeDoubleHashedLeaf() public {
  bytes32 a=keccak256("left"); bytes32 b=keccak256("right");
  if(a>b) (a,b)=(b,a);
  bytes32 root=keccak256(abi.encode(a,b));
  Distributor d=new Distributor(root);
  bytes32[] memory p=new bytes32[](0);
  (bool ok,)=address(d).call(abi.encodeCall(d.claim,(a,b,p)));
  require(!ok&&!d.claimed(),"internal node accepted");
  require(MerkleProof.verify(p,root,keccak256(abi.encode(a,b))),"single hash control");
  Distributor honest=new Distributor(keccak256(bytes.concat(keccak256(abi.encode(a,b)))));
  honest.claim(a,b,p); require(honest.claimed(),"valid leaf rejected");
 }
}

