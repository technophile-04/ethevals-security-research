// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

contract Encoder {
 function pack(bytes calldata x, uint128[2] calldata a) external pure returns(bytes memory) { return abi.encode(x,a); }
 function affected(bytes calldata x, uint256[2] calldata a) external pure returns(bytes memory) { return abi.encode(x,a); }
}
contract Proof {
 function testUint128TailPreservesDynamicBytes() public {
  Encoder e = new Encoder();
  uint128[2] memory a = [uint128(7),uint128(9)];
  bytes memory out = e.pack(hex"11223344",a);
  (bytes memory x,uint128[2] memory b)=abi.decode(out,(bytes,uint128[2]));
  require(keccak256(x)==keccak256(hex"11223344") && b[0]==7 && b[1]==9,"narrow array corrupted");
  uint256[2] memory wide=[uint256(7),uint256(9)];
  (bytes memory corrupt,)=abi.decode(e.affected(hex"11223344",wide),(bytes,uint256[2]));
  require(corrupt.length==0,"positive control must expose bug");
 }
}

