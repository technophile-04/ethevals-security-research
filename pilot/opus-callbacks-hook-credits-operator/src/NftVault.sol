pragma solidity 0.8.28;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NftVault {
    IERC721 public immutable nft;
    mapping(uint256 => address) public depositor;
    constructor(IERC721 n) { nft = n; }

    function onERC721Received(address from, address, uint256 id, bytes calldata)
        external returns (bytes4)
    {
        require(msg.sender == address(nft), "wrong collection");
        depositor[id] = from;
        return this.onERC721Received.selector;
    }

    function withdraw(uint256 id) external {
        require(depositor[id] == msg.sender, "not yours");
        nft.transferFrom(address(this), msg.sender, id);
        delete depositor[id];
    }
}
