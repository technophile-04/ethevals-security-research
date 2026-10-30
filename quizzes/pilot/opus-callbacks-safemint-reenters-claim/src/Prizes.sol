pragma solidity 0.8.28;
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Prizes is ERC721("Trophy", "TRO") {
    IERC20 public immutable usdc;
    mapping(address => uint256) public wins;
    uint256 public nextId;
    constructor(IERC20 t) { usdc = t; }

    function claim() external {
        uint256 n = wins[msg.sender];
        for (uint256 i; i < n; i++) {
            require(usdc.transfer(msg.sender, 100e6));
            _safeMint(msg.sender, nextId++);
        }
        wins[msg.sender] = 0;
    }
}
