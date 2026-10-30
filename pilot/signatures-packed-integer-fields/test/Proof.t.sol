// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract PermitHash {
 function digest(address o,address s,uint256 value,uint256 nonce,uint256 deadline) external pure returns(bytes32) {
  return keccak256(abi.encodePacked(o,s,value,nonce,deadline));
 }
}
contract Proof {
 function testDecimalBoundaryShiftDoesNotPreserveDigest() public {
  PermitHash h=new PermitHash();
  bytes32 x=h.digest(address(1),address(2),10000,0,1500);
  bytes32 y=h.digest(address(1),address(2),100000,1,500);
  require(x!=y,"numeric collision");
  require(keccak256(abi.encodePacked("10000","0","1500"))==keccak256(abi.encodePacked("100000","1","500")),"string positive control");
 }
 function testFuzzFixedWidths(uint256 a,uint256 b,uint256 c,uint256 x,uint256 y,uint256 z) public pure {
  bytes memory lhs=abi.encodePacked(a,b,c);
  bytes memory rhs=abi.encodePacked(x,y,z);
  require((keccak256(lhs)==keccak256(rhs))==(a==x&&b==y&&c==z),"fixed width changed meaning");
 }
}

