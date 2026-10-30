// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {vm} from "lib/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BridgeV2, BridgeV4, Manager, Receipt, Sig} from "../src/Bridge.sol";

contract Proof {
    Manager manager;
    address payable proxy;
    address admin = address(0xAD);
    address stranger = address(0x5157);

    function setUp() public {
        manager = new Manager();
        manager.set(address(0x1001), 40);
        manager.set(address(0x1002), 30);
        manager.set(address(0x1003), 30);
        BridgeV2 v2 = new BridgeV2();
        proxy = payable(address(new ERC1967Proxy(address(v2), abi.encodeCall(BridgeV2.initialize, (manager, admin)))));
        BridgeV2(proxy).initializeV2();
        vm.deal(proxy, 4000 ether);
    }

    function _upgradeWithV4Only() internal {
        BridgeV4 impl = new BridgeV4();
        vm.prank(admin);
        BridgeV2(proxy).upgradeToAndCall(address(impl), abi.encodeCall(BridgeV4.initializeV4, (address(0x9e7))));
    }

    function testUpgradeSkipsV3AndQuorumIsZero() public {
        _upgradeWithV4Only();
        BridgeV4 b = BridgeV4(proxy);
        require(b.version() == 4, "version not 4");
        require(b.cache() == 0, "cache set");
        // A receipt with no operator signatures is paid.
        Sig[] memory none = new Sig[](0);
        vm.prank(stranger);
        b.withdraw(Receipt(stranger, 4000 ether, 1), none);
        require(stranger.balance == 4000 ether, "not paid");
    }

    function testInitializeV3CanNeverRunAfterwards() public {
        _upgradeWithV4Only();
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        BridgeV4(proxy).initializeV3();
    }

    // Control: had the upgrade run V3 (then V4), the same empty receipt fails quorum.
    function testWithV3TheEmptyReceiptFails() public {
        BridgeV4 impl = new BridgeV4();
        vm.prank(admin);
        BridgeV2(proxy).upgradeToAndCall(address(impl), abi.encodeCall(BridgeV4.initializeV3, ()));
        BridgeV4(proxy).initializeV4(address(0x9e7));
        Sig[] memory none = new Sig[](0);
        vm.expectRevert(bytes("quorum"));
        BridgeV4(proxy).withdraw(Receipt(stranger, 4000 ether, 1), none);
    }
}
