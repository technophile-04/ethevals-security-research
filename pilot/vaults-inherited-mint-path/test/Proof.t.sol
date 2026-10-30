// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {vm} from "lib/Vm.sol";
import {StakedEth, WETH} from "../src/StakedEth.sol";

contract Proof {
    WETH weth;
    StakedEth vault;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        weth = new WETH();
        vault = new StakedEth(weth);
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        vault.depositETH{value: 100 ether}(alice);
    }

    // Controls: both overridden entry points collect the asset.
    function testDepositPathsCollectAssets() public {
        require(weth.balanceOf(address(vault)) == 100 ether, "depositETH did not wrap");
        require(vault.balanceOf(alice) == 100 ether, "alice shares");
        vm.prank(bob);
        vm.expectRevert(); // no WETH, no allowance: safeTransferFrom fails
        vault.deposit(10 ether, bob);
    }

    // The inherited public mint() calls the overridden _deposit, which no longer pulls WETH.
    function testInheritedMintIsFree() public {
        require(weth.balanceOf(bob) == 0 && bob.balance == 0, "bob funded");
        vm.prank(bob);
        uint256 assets = vault.mint(1_000 ether, bob);
        require(assets == 1_000 ether, "quoted assets");
        require(vault.balanceOf(bob) == 1_000 ether, "bob shares");
        require(weth.balanceOf(address(vault)) == 100 ether, "vault WETH changed");
        // Bob's free shares now redeem most of Alice's WETH.
        vm.prank(bob);
        uint256 out = vault.redeem(1_000 ether, bob, bob);
        require(out > 90 ether, "redeem");
        require(weth.balanceOf(bob) == out, "bob WETH");
    }
}
