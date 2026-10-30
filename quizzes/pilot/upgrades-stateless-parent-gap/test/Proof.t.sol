// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => uint256) public balanceOf;
    function initialize() external initializer { __Ownable_init(); __UUPSUpgradeable_init(); }
    function credit(address a, uint256 x) external onlyOwner { balanceOf[a] += x; }
    function _authorizeUpgrade(address) internal override onlyOwner {}
}

contract VaultV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable, MulticallUpgradeable {
    mapping(address => uint256) public balanceOf;
    function credit(address a, uint256 x) external onlyOwner { balanceOf[a] += x; }
    function _authorizeUpgrade(address) internal override onlyOwner {}
}

contract Proof {
    function testAppendedMulticallMovesBalances() public {
        address alice = address(0xA11CE);
        ERC1967Proxy p = new ERC1967Proxy(address(new VaultV1()), abi.encodeCall(VaultV1.initialize, ()));
        VaultV1(address(p)).credit(alice, 100 ether);
        VaultV1(address(p)).upgradeTo(address(new VaultV2()));
        VaultV2 v2 = VaultV2(address(p));
        require(v2.owner() == address(this), "owner moved");
        require(v2.balanceOf(alice) == 0, "balance survived");
    }
}
