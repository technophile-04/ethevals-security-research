// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "oz/proxy/utils/UUPSUpgradeable.sol";
import "oz/access/Ownable.sol";
import "oz/proxy/utils/Initializable.sol";
interface Vm {function prank(address) external;}
contract Logic is UUPSUpgradeable,Ownable,Initializable {
 function initialize(address operator) external initializer {_transferOwnership(operator);}
 function _authorizeUpgrade(address) internal override onlyOwner {}
 function version() external pure virtual returns(uint256) {return 1;}
}
contract Replacement is Logic {
 function version() external pure override returns(uint256) {return 2;}
}
contract Proof {
 Vm constant vm=Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
 function testImplementationOwnerUpgradesWithoutProxyAdmin() public {
  address admin=address(0xAD);address operator=address(0xB0B);
  Logic implementation=new Logic(); Replacement replacement=new Replacement();
  TransparentUpgradeableProxy p=new TransparentUpgradeableProxy(address(implementation),admin,abi.encodeCall(implementation.initialize,(operator)));
  vm.prank(address(0xBAD));
  (bool denied,)=address(p).call(abi.encodeCall(implementation.upgradeTo,(address(replacement))));
  require(!denied,"unprivileged upgrade");
  vm.prank(operator);Logic(address(p)).upgradeTo(address(replacement));
  require(Logic(address(p)).version()==2,"operator failed to upgrade");
 }
}

