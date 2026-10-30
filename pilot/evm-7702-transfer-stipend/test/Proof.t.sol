// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface Vm {
    struct SignedDelegation { uint8 v; bytes32 r; bytes32 s; uint64 nonce; address implementation; }
    function signAndAttachDelegation(address implementation, uint256 privateKey) external returns (SignedDelegation memory);
    function addr(uint256) external returns (address);
}

contract Wallet { // the delegate's receive(): one event
    event Received(address indexed from, uint256 amount);
    receive() external payable { emit Received(msg.sender, msg.value); }
}
contract HeavyWallet { uint256 a; uint256 b; receive() external payable { require(a == 0 && b == 0); } }

contract Payouts {
    constructor() payable {}
    function pay(address payable user, uint256 amount) external { user.transfer(amount); }
}

contract Proof {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testTransferToDelegatedEoaSucceeds() public {
        Payouts p = new Payouts{value: 1 ether}();
        address user = vm.addr(0xA1);
        vm.signAndAttachDelegation(address(new Wallet()), 0xA1);
        p.pay(payable(user), 0.1 ether);
        require(user.code.length == 23, "not delegated");
        require(user.balance == 0.1 ether, "not paid");
    }
    // Control: the 2,300 stipend still binds; a receive() with two cold SLOADs fails.
    function testHeavyReceiveStillFails() public {
        Payouts p = new Payouts{value: 1 ether}();
        address user = vm.addr(0xA2);
        vm.signAndAttachDelegation(address(new HeavyWallet()), 0xA2);
        (bool ok,) = address(p).call(abi.encodeCall(p.pay, (payable(user), 0.1 ether)));
        require(!ok && user.code.length == 23, "heavy receive succeeded");
    }
}
