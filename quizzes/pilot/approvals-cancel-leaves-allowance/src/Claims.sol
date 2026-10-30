// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Token is ERC20 {
    constructor() ERC20("Bonus", "BONUS") {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

// createCampaign and cancelCampaign are the instruction's snippet, verbatim.
contract Claims is ReentrancyGuard {
    using SafeERC20 for IERC20;
    struct Campaign { address manager; IERC20 token; uint256 amount; address locker; bytes32 root; }
    mapping(bytes16 => Campaign) public campaigns;

    function createCampaign(bytes16 id, IERC20 token, uint256 amount, address locker, bytes32 root) external {
        require(campaigns[id].manager == address(0), "exists");
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeIncreaseAllowance(locker, amount);
        campaigns[id] = Campaign(msg.sender, token, amount, locker, root);
    }

    function cancelCampaign(bytes16 id) external nonReentrant {
        Campaign memory c = campaigns[id];
        require(msg.sender == c.manager, "not manager");
        delete campaigns[id];
        c.token.safeTransfer(c.manager, c.amount);
    }
}

// The manager's own "locker".
contract Puller {
    function pull(IERC20 token, address from, address to, uint256 amount) external { token.transferFrom(from, to, amount); }
}
