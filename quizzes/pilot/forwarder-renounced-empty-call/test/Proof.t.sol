// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "old/metatx/ERC2771Context.sol";
import "old/access/Ownable.sol";
import {ERC2771Context as FixedContext} from "oz/metatx/ERC2771Context.sol";
contract RawForwarder {
 function forwardEmpty(address target) external returns(bool) { (bool ok,)=target.call("");return ok; }
}
contract Treasury is ERC2771Context,Ownable {
 bool public paid;
 constructor(address f) ERC2771Context(f) {}
 receive() external payable onlyOwner { paid=true; }
 function _msgSender() internal view override(Context,ERC2771Context) returns(address) {return ERC2771Context._msgSender();}
 function _msgData() internal view override(Context,ERC2771Context) returns(bytes calldata) {return ERC2771Context._msgData();}
}
contract FixedTreasury is FixedContext {
 address public owner; bool public paid;
 constructor(address f) FixedContext(f) {owner=address(0);}
 receive() external payable {require(_msgSender()==owner,"owner");paid=true;}
}
contract Proof {
 function testEmptyForwardedCallPassesRenouncedOnlyOwner() public {
  RawForwarder f=new RawForwarder(); Treasury t=new Treasury(address(f));
  t.renounceOwnership(); require(t.owner()==address(0),"not renounced");
  require(f.forwardEmpty(address(t))&&t.paid(),"zero sender did not pass");
  FixedTreasury fixedT=new FixedTreasury(address(f));
  require(!f.forwardEmpty(address(fixedT))&&!fixedT.paid(),"patch failed");
 }
}

