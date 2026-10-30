// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// OpenZeppelin Contracts Upgradeable 5.4
contract VaultV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => uint256) public balanceOf;
    function initialize(address owner_) external initializer { __Ownable_init(owner_); __UUPSUpgradeable_init(); }
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
