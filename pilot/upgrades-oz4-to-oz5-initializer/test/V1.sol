// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "oz4u/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "oz4u/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "oz4u/proxy/utils/UUPSUpgradeable.sol";

// OpenZeppelin Contracts Upgradeable 4.9.6
contract VaultV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => uint256) public balanceOf;
    function initialize(address owner_) external initializer { __Ownable_init(); transferOwnership(owner_); __UUPSUpgradeable_init(); }
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
