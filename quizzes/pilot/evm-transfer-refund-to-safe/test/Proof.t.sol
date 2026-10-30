// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import {Safe} from "safe/Safe.sol";
import {SafeProxyFactory} from "safe/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "safe/proxies/SafeProxy.sol";
import {Enum} from "safe/common/Enum.sol";

interface Vm { function prank(address) external; function deal(address, uint256) external; function cool(address) external; }

contract Shop { // refunds overpayment to whoever paid
    uint256 public constant PRICE = 0.9 ether;
    function buy() external payable { msg.sender.transfer(msg.value - PRICE); }
    function refund(address payable to, uint256 amount) external { to.transfer(amount); }
    receive() external payable {}
}

contract Proof {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant OWNER = address(0xA11CE);

    function _newSafe(Safe singleton, SafeProxyFactory f, uint256 salt) internal returns (Safe s) {
        address[] memory owners = new address[](1); owners[0] = OWNER;
        bytes memory init = abi.encodeWithSelector(Safe.setup.selector, owners, 1, address(0), "", address(0), address(0), 0, address(0));
        s = Safe(payable(address(f.createProxyWithNonce(address(singleton), init, salt))));
        vm.deal(address(s), 5 ether);
    }
    function _exec(Safe s, address to, uint256 value, bytes memory data) internal returns (bool ok) {
        // signature type 1: approved by msg.sender, who is the owner
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(OWNER))), bytes32(0), uint8(1));
        vm.prank(OWNER);
        ok = s.execTransaction(to, value, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), sig);
    }

    // Safe pays the shop and gets its refund via transfer() inside the same call
    function testRefundToCallingSafe() public {
        Safe singleton = new Safe(); SafeProxyFactory f = new SafeProxyFactory(); Shop shop = new Shop();
        Safe s = _newSafe(singleton, f, 1);
        uint256 before = address(s).balance;
        bool ok = _exec(s, address(shop), 1 ether, abi.encodeWithSelector(Shop.buy.selector));
        require(ok, "execTransaction reported failure");
        require(address(s).balance == before - 0.9 ether, "refund not received");
    }
    // Control: the same direct transfer succeeds when the Safe was touched earlier in the transaction
    function testTransferToWarmSafeSucceeds() public {
        Safe singleton = new Safe(); SafeProxyFactory f = new SafeProxyFactory(); Shop shop = new Shop();
        vm.deal(address(shop), 1 ether);
        Safe s = _newSafe(singleton, f, 3); // deployment and setup leave proxy, slot 0 and singleton warm
        shop.refund(payable(address(s)), 0.1 ether);
        require(address(s).balance == 5.1 ether, "warm transfer failed");
    }
    // Control: transfer() to a Safe whose proxy and singleton are cold fails
    function testTransferToColdSafeFails() public {
        Safe singleton = new Safe(); SafeProxyFactory f = new SafeProxyFactory(); Shop shop = new Shop();
        vm.deal(address(shop), 1 ether);
        Safe s = _newSafe(singleton, f, 2);
        vm.cool(address(s)); vm.cool(address(singleton));
        (bool ok,) = address(shop).call(abi.encodeWithSelector(Shop.refund.selector, address(s), 0.1 ether));
        require(!ok, "cold transfer succeeded");
    }
}
