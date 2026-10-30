// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Manager {
    mapping(address => uint256) public weightOf;
    uint256 public totalWeight;
    function set(address op, uint256 w) external { totalWeight = totalWeight - weightOf[op] + w; weightOf[op] = w; }
}

struct Receipt { address to; uint256 amount; uint256 id; }
struct Sig { address signer; } // signature checks are out of scope; the proof sends none

// Version 2 of the bridge: initialize() then initializeV2().
contract BridgeV2 is Initializable, UUPSUpgradeable {
    Manager public manager;
    address public admin;
    address public weth;
    constructor() { _disableInitializers(); }
    function initialize(Manager m, address a) external initializer { manager = m; admin = a; }
    function initializeV2() external reinitializer(2) {}
    function _authorizeUpgrade(address) internal view override { require(msg.sender == admin, "admin"); }
}

// Version 3/4: the snippet in the instruction.
contract BridgeV4 is Initializable, UUPSUpgradeable {
    Manager public manager;
    address public admin;
    address public weth;
    uint256 private totalWeightCache;
    mapping(uint256 => bool) public paid;

    constructor() { _disableInitializers(); }

    function initializeV3() external reinitializer(3) {
        totalWeightCache = manager.totalWeight();
    }

    function initializeV4(address newWeth) external reinitializer(4) {
        weth = newWeth;
    }

    function withdraw(Receipt calldata r, Sig[] calldata sigs) external {
        uint256 signed = _sumVerifiedWeight(keccak256(abi.encode(r)), sigs);
        require(signed * 10 >= totalWeightCache * 7, "quorum");
        _release(r);
    }

    function _sumVerifiedWeight(bytes32, Sig[] calldata sigs) internal view returns (uint256 w) {
        address last;
        for (uint256 i; i < sigs.length; i++) {
            require(sigs[i].signer > last, "order");
            last = sigs[i].signer;
            w += manager.weightOf(sigs[i].signer);
        }
    }

    function _release(Receipt calldata r) internal {
        require(!paid[r.id], "paid");
        paid[r.id] = true;
        payable(r.to).transfer(r.amount);
    }

    function version() external view returns (uint64) { return _getInitializedVersion(); }
    function cache() external view returns (uint256) { return totalWeightCache; }
    function _authorizeUpgrade(address) internal view override { require(msg.sender == admin, "admin"); }
    receive() external payable {}
}
