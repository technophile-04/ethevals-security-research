pragma solidity 0.8.28;
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Heroes is ERC721("Heroes", "HERO") {
    mapping(uint256 => bool) public pledged;

    function transferFrom(address from, address to, uint256 id) public override {
        require(!pledged[id], "pledged");
        super.transferFrom(from, to, id);
    }
}

contract Gear is ERC1155("") {
    mapping(address => mapping(uint256 => uint256)) public pledged;

    function safeTransferFrom(address from, address to, uint256 id, uint256 n, bytes memory data)
        public override
    {
        require(balanceOf(from, id) >= pledged[from][id] + n, "pledged");
        super.safeTransferFrom(from, to, id, n, data);
    }
}
