// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VaultV1} from "./V1.sol";
import {VaultV2} from "./V2.sol";

interface Vm { function prank(address) external; }

contract Proof {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant SAFE = address(0x5AFE);
    address constant STRANGER = address(0xBAD);

    function _upgraded() internal returns (VaultV2 v) {
        ERC1967Proxy p = new ERC1967Proxy(address(new VaultV1()), abi.encodeCall(VaultV1.initialize, (SAFE)));
        require(VaultV1(address(p)).owner() == SAFE, "v1 owner");
        // V1 cannot be initialized twice
        (bool again,) = address(p).call(abi.encodeCall(VaultV1.initialize, (STRANGER)));
        require(!again, "v1 re-init");
        address v2impl = address(new VaultV2());
        vm.prank(SAFE);
        VaultV1(address(p)).upgradeTo(v2impl);
        v = VaultV2(address(p));
    }
    function testOwnerReadsZeroAfterUpgrade() public {
        VaultV2 v = _upgraded();
        require(v.owner() == address(0), "owner survived");
    }
    function testStrangerInitializesV2() public {
        VaultV2 v = _upgraded();
        vm.prank(STRANGER);
        v.initialize(STRANGER);
        require(v.owner() == STRANGER, "stranger not owner");
    }
}
