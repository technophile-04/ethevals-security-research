// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "oz/metatx/ERC2771Context.sol";
import "oz/utils/Multicall.sol";
interface Vm { function prank(address) external; }
contract Forwarder {
 function forward(address target, bytes memory data) external returns(bool) {
  (bool ok,)=target.call(bytes.concat(data,bytes20(msg.sender))); return ok;
 }
}
contract Treasury is ERC2771Context, Multicall {
 address public owner; bool public paid;
 constructor(address f,address o) ERC2771Context(f) { owner=o; }
 function payout() external { require(_msgSender()==owner,"owner"); paid=true; }
 function _msgSender() internal view override(Context,ERC2771Context) returns(address) { return ERC2771Context._msgSender(); }
 function _msgData() internal view override(Context,ERC2771Context) returns(bytes calldata) { return ERC2771Context._msgData(); }
 function _contextSuffixLength() internal view override(Context,ERC2771Context) returns(uint256) { return ERC2771Context._contextSuffixLength(); }
}
contract Proof {
 Vm constant vm=Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
 function testForgedInnerOwnerDoesNotAuthorize() public {
  Forwarder f=new Forwarder(); address owner=address(0xA11CE); Treasury t=new Treasury(address(f),owner);
  bytes[] memory calls=new bytes[](1);
  calls[0]=bytes.concat(abi.encodeCall(t.payout,()),bytes20(owner));
  require(!f.forward(address(t),abi.encodeCall(t.multicall,(calls))),"spoof accepted");
  require(!t.paid(),"paid attacker");
  vm.prank(owner);
  require(f.forward(address(t),abi.encodeCall(t.multicall,(calls))),"real owner rejected");
  require(t.paid(),"owner not paid");
 }
}

