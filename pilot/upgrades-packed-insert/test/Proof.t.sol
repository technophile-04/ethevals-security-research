// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract VaultV1 {
    address public owner;
    bool public paused;
    mapping(address => uint256) public balances;
    function init(address o) external { require(owner == address(0)); owner = o; }
    function credit(address a, uint256 x) external { require(msg.sender == owner); balances[a] += x; }
    function setPaused(bool p) external { require(msg.sender == owner); paused = p; }
    function upgradeTo(address impl) external { require(msg.sender == owner); ERC1967Utils.upgradeToAndCall(impl, ""); }
}

contract VaultV2 {
    address public owner;
    bool public paused;
    uint64 public feeBps;
    mapping(address => uint256) public balances;
    function upgradeTo(address impl) external { require(msg.sender == owner); ERC1967Utils.upgradeToAndCall(impl, ""); }
}

contract Proof {
    function testInsertedFieldPacksIntoSlotZero() public {
        address alice = address(0xA11CE);
        ERC1967Proxy p = new ERC1967Proxy(address(new VaultV1()), abi.encodeCall(VaultV1.init, (address(this))));
        VaultV1(address(p)).credit(alice, 100 ether);
        VaultV1(address(p)).setPaused(true);
        VaultV1(address(p)).upgradeTo(address(new VaultV2()));
        VaultV2 v2 = VaultV2(address(p));
        require(v2.balances(alice) == 100 ether, "balance moved");
        require(v2.owner() == address(this), "owner moved");
        require(v2.paused(), "paused moved");
        require(v2.feeBps() == 0, "fee not zero");
    }
}
