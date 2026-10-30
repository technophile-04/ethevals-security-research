// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CreditPool} from "../src/CreditPool.sol";

contract USDC is ERC20("USD Coin", "USDC") {
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 v) external { _mint(to, v); }
}

contract CreditPoolProof is Proof {
    USDC usdc;
    CreditPool pool;
    address deployer = address(0xD3);
    address borrower = address(0xB022);
    address alice = address(0xA11CE);

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new USDC();
        pool = new CreditPool(usdc, borrower);
        address[3] memory users = [deployer, borrower, alice];
        for (uint256 i = 0; i < 3; i++) {
            usdc.mint(users[i], 20_000_000e6);
            vm.prank(users[i]);
            usdc.approve(address(pool), type(uint256).max);
        }
        // Launch deposit; its shares are burned.
        vm.startPrank(deployer);
        pool.deposit(1_000_000e6);
        pool.transfer(address(0xdEaD), pool.balanceOf(deployer));
        vm.stopPrank();
    }

    // Issue 1: the 5,000,000 USDC cap is compared with the share supply. Once interest
    // lifts the share price above 1 USDC, the pool takes more than 5,000,000 USDC.
    function test_issue1_capCountsSharesNotUsdc() public {
        vm.prank(borrower);
        pool.borrow(800_000e6);
        vm.warp(block.timestamp + 365 days);
        pool.accrue(); // owed 800,000 -> 880,000; price 1.08 USDC per share
        uint256 room = 5_000_000e6 - pool.totalSupply();
        uint256 amount = room * pool.totalAssets() / pool.totalSupply();
        vm.prank(alice);
        pool.deposit(amount);
        uint256 supplied = 1_000_000e6 + amount;
        assertGt(supplied, 5_300_000e6, "lenders supplied over 5.3M USDC under a 5M cap");
        assertTrue(pool.totalSupply() <= 5_000_000e6, "share supply is at the cap");
    }

    function test_issue1_control_capHoldsAtPriceOne() public {
        vm.prank(alice);
        vm.expectRevert();
        pool.deposit(4_000_001e6); // 1M + 4,000,001 > 5M at a price of 1
    }

    // Issue 2: borrow checks the one-fifth cash rule before lending, so a single draw can
    // take every dollar of cash and lenders cannot redeem.
    function test_issue2_reserveCheckedBeforeDraw() public {
        vm.prank(alice);
        pool.deposit(4_000_000e6); // 5,000,000 USDC of cash
        vm.prank(borrower);
        pool.borrow(5_000_000e6);  // check saw 100% cash; leaves 0%
        assertEq(usdc.balanceOf(address(pool)), 0, "no cash left for withdrawals");
        uint256 shares = pool.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert();
        pool.redeem(shares / 100); // even 1% of her position cannot leave
        // The rule bites only on the next draw, after the damage is done.
        vm.prank(borrower);
        vm.expectRevert();
        pool.borrow(1);
    }
}
