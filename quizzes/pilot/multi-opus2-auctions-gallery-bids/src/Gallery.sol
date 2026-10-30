// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
contract Gallery is Ownable(msg.sender) {
    struct Bid { address bidder; uint256 amount; }
    IERC721 immutable nft;
    mapping(uint256 => uint256) public endTime;
    mapping(uint256 => Bid[]) public bids;
    mapping(uint256 => bool) settled;

    constructor(IERC721 n) { nft = n; }

    function list(uint256 id, uint256 end) external onlyOwner {
        require(endTime[id] == 0);
        endTime[id] = end;
    }

    function bid(uint256 id) external payable {
        Bid[] storage b = bids[id];
        require(block.timestamp <= endTime[id] && (b.length == 0 || msg.value > b[b.length - 1].amount));
        b.push(Bid(msg.sender, msg.value));
    }

    function cancel(uint256 id, uint256 i) external {
        Bid storage x = bids[id][i];
        require(block.timestamp <= endTime[id] && i + 1 < bids[id].length && x.bidder == msg.sender);
        uint256 amount = x.amount;
        x.amount = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok);
    }

    function settle(uint256 id) external {
        require(block.timestamp >= endTime[id] && !settled[id]);
        settled[id] = true;
        Bid[] storage b = bids[id];
        Bid storage top = b[b.length - 1];
        nft.transferFrom(nft.ownerOf(id), top.bidder, id);
        (bool ok,) = owner().call{value: top.amount}("");
        require(ok);
        for (uint256 i = 0; i + 1 < b.length; i++) {
            (ok,) = b[i].bidder.call{value: b[i].amount}("");
            require(ok);
        }
    }
}
