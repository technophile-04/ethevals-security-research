// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {FarmVault, IGauge} from "../src/FarmVault.sol";

contract USDC is ERC20("USD Coin", "USDC") {
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 v) external { _mint(to, v); }
}

// Unmodified OpenZeppelin 5.4.0 ERC4626.
contract Pool is ERC4626 {
    constructor(IERC20 a) ERC20("Pool USDC", "pUSDC") ERC4626(a) {}
}

contract Gauge is IGauge {
    USDC public usdc;
    mapping(address => uint256) public pending;
    constructor(USDC u) { usdc = u; }
    function accrue(address to, uint256 v) external { usdc.mint(address(this), v); pending[to] += v; }
    function claim() external { uint256 v = pending[msg.sender]; pending[msg.sender] = 0; usdc.transfer(msg.sender, v); }
}

contract FarmVaultProof is Proof {
    USDC usdc;
    Pool pool;
    Gauge gauge;
    FarmVault vault;
    address deployer = address(0xD3);
    address dead = address(0xdEaD);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        usdc = new USDC();
        pool = new Pool(usdc);
        gauge = new Gauge(usdc);
        vault = new FarmVault(IERC4626(address(pool)), gauge);
        address[3] memory users = [deployer, alice, bob];
        for (uint256 i = 0; i < 3; i++) {
            usdc.mint(users[i], 100_000e6);
            vm.prank(users[i]);
            usdc.approve(address(vault), type(uint256).max);
        }
        // Launch: deployer deposits 1,000 USDC and burns the shares.
        vm.startPrank(deployer);
        vault.deposit(1_000e6);
        vault.transfer(dead, vault.balanceOf(deployer));
        vm.stopPrank();
    }

    function claimOf(address a) internal view returns (uint256) {
        return vault.balanceOf(a) * vault.totalAssets() / vault.totalSupply();
    }

    // Issue 1: shares are priced after the deposit has been pulled in, so the deposit is
    // counted in totalAssets and the depositor is minted too few shares.
    function test_issue1_depositPricedAfterTransfer() public {
        assertEq(vault.totalAssets(), 1_000e6, "price is 1 USDC per share");
        assertEq(vault.totalSupply(), 1_000e6, "supply");
        vm.prank(alice);
        vault.deposit(1_000e6);
        assertEq(vault.balanceOf(alice), 500e6, "alice minted 500 shares, not 1,000");
        uint256 c = claimOf(alice);
        assertLt(c, 667e6, "alice's 1,000 USDC is now worth about 666.67 USDC");
        assertGt(c, 666e6, "about 666.67");
    }

    // Issue 2: redeem passes an asset amount to pool.redeem, which takes pool shares,
    // so once a pool share is worth more than 1 USDC the redeemer is overpaid.
    function test_issue2_assetAmountPassedAsPoolShares() public {
        vm.prank(alice);
        vault.deposit(1_000e6);
        // The pool earns 10%: its share price goes from 1.0 to 1.1 USDC.
        usdc.mint(address(pool), pool.totalAssets() / 10);
        uint256 owed = claimOf(alice);
        uint256 launchBefore = claimOf(dead);
        uint256 before = usdc.balanceOf(alice);
        uint256 shares = vault.balanceOf(alice);
        vm.prank(alice);
        vault.redeem(shares);
        uint256 paid = usdc.balanceOf(alice) - before;
        assertGt(paid, owed + owed / 20, "alice is paid about 10% more than her shares are worth");
        // The overpayment came out of the launch shares' backing.
        assertLt(claimOf(dead) + owed / 20, launchBefore, "launch shares lost more than 5% of alice's claim");
    }

    // Issue 3: deposit and redeem do not harvest first, so rewards already earned for the
    // existing holders are shared with whoever deposits just before harvest().
    function test_issue3_depositBeforeHarvestSharesEarlierRewards() public {
        gauge.accrue(address(vault), 100e6); // earned while only the launch shares existed
        vm.prank(bob);
        vault.deposit(1_000e6);
        uint256 beforeHarvest = claimOf(bob);
        vault.harvest();
        uint256 afterHarvest = claimOf(bob);
        assertGt(afterHarvest, beforeHarvest + 30e6, "bob collects over 30 USDC of rewards earned before he joined");
        // The launch shares earned all 100 USDC but gain less than 70 USDC from the harvest.
        assertLt(vault.balanceOf(dead) * 100e6 / vault.totalSupply(), 70e6, "launch holders keep under 70 of their 100");
    }

    // Control for issue 3: depositing after harvest gives no share of the earlier rewards.
    function test_issue3_control_depositAfterHarvest() public {
        gauge.accrue(address(vault), 100e6);
        vault.harvest();
        vm.prank(bob);
        vault.deposit(1_000e6);
        uint256 c = claimOf(bob);
        vault.harvest();
        assertEq(claimOf(bob), c, "no later rewards, no change");
    }
}
