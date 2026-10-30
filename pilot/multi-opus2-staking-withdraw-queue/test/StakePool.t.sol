// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {StakePool, IStaker} from "../src/StakePool.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Trusted staking backend as the setup describes: unstake pays the caller within the call,
// and staked() falls when a validator is slashed. Reverts from the caller bubble up.
contract MockStaker is IStaker {
    uint256 public staked;
    function stake() external payable { staked += msg.value; }
    function unstake(uint256 amount) external {
        staked -= amount;
        (bool ok, bytes memory ret) = msg.sender.call{value: amount}("");
        if (!ok) assembly { revert(add(ret, 32), mload(ret)) }
    }
    function slash(uint256 amount) external {
        staked -= amount;
        payable(address(0xdead)).transfer(amount);
    }
}

contract StakePoolProof is Proof {
    MockStaker staker;
    StakePool pool;
    address keeper = address(0x4EE);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA);
    address deployer = address(0xD0);

    function setUp() public {
        staker = new MockStaker();
        pool = new StakePool(IStaker(address(staker)), keeper);
        vm.deal(deployer, 32 ether);
        vm.startPrank(deployer);
        pool.deposit{value: 32 ether}();
        pool.transfer(address(0xdead), 32 ether);   // seed shares burned, as the setup says
        vm.stopPrank();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
        vm.prank(alice);
        pool.deposit{value: 32 ether}();
        vm.prank(bob);
        pool.deposit{value: 32 ether}();
    }

    // Issue 1: ETH owed to requested withdrawals still counts in totalAssets, so after a request every
    // remaining share is overvalued: later requests are owed more than the pool holds, and new deposits get too few shares.
    function test_issue1_owedEthStillCountedInTotalAssets() public {
        vm.prank(alice);
        pool.requestWithdraw(32 ether);
        assertEq(pool.owed(alice), 32 ether, "alice is owed her 32 ETH");
        assertEq(pool.totalAssets(), 96 ether, "but the 32 ETH owed to her is still counted");

        vm.prank(carol);
        pool.deposit{value: 32 ether}();
        assertLt(pool.balanceOf(carol), 22 ether, "carol gets ~21.3 shares for 32 ETH instead of 32");

        vm.prank(bob);
        pool.requestWithdraw(32 ether);
        uint256 promised = pool.owed(alice) + pool.owed(bob);
        assertGt(promised, 32 ether + 32 ether + 1 ether, "owed to alice and bob exceeds what they put in");

        vm.prank(alice);
        pool.claim();
        vm.prank(bob);
        pool.claim();                                  // bob takes part of carol's and the seed's ETH
        assertGt(bob.balance, 100 ether + 1 ether, "bob withdrew more than he deposited with no yield");
    }

    // Issue 2: the amount is fixed at request time, so a slash after the request is borne only by holders still in the pool.
    function test_issue2_requestBeforeSlashEscapesTheLoss() public {
        vm.prank(keeper);
        pool.rebalance(96 ether, 0);                   // everything staked
        vm.prank(alice);
        pool.requestWithdraw(32 ether);                // alice requests at the pre-slash price
        staker.slash(24 ether);                        // a 25% slash lands after her request
        // keeper cannot bring ETH back (issue 3), so fund alice's claim from a fresh deposit for this test
        vm.prank(carol);
        pool.deposit{value: 32 ether}();
        uint256 before = alice.balance;
        vm.prank(alice);
        pool.claim();
        assertEq(alice.balance - before, 32 ether, "alice is paid in full despite the 25% slash");
    }

    // Issue 3: receive() is nonReentrant, and rebalance (also nonReentrant) calls unstake, which sends ETH back
    // into receive() inside the same call, so ETH can never come back from staking.
    function test_issue3_unstakeAlwaysRevertsOnNonReentrantReceive() public {
        vm.prank(keeper);
        pool.rebalance(96 ether, 0);
        vm.prank(keeper);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        pool.rebalance(0, 1 ether);
        vm.prank(alice);
        pool.requestWithdraw(32 ether);
        vm.prank(alice);
        vm.expectRevert();
        pool.claim();                                  // nothing liquid, and nothing can be brought back
    }

    // Control for issue 3: staking works; only the return path fails.
    function test_control_stakePathWorks() public {
        vm.prank(keeper);
        pool.rebalance(10 ether, 0);
        assertEq(staker.staked(), 10 ether, "stake path works");
    }

    // Control for issue 2: with no slash, alice receives exactly her deposit.
    function test_control_noSlashFairExit() public {
        vm.prank(alice);
        pool.requestWithdraw(32 ether);
        uint256 before = alice.balance;
        vm.prank(alice);
        pool.claim();
        assertEq(alice.balance - before, 32 ether, "fair exit");
    }
}
