// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Grants {
    using SafeERC20 for IERC20;
    struct Grant { address grantee; uint256 amount; uint256 withdrawn; uint64 start; uint64 end; }
    IERC20 immutable token;
    Grant[] grants;

    constructor(IERC20 t) { token = t; }

    function fund(address sponsor, address grantee, uint256 amount, uint64 start, uint64 end) external {
        require(start < end);
        token.safeTransferFrom(sponsor, address(this), amount);
        grants.push(Grant(grantee, amount, 0, start, end));
    }

    function unlocked(uint256 id) public view returns (uint256) {
        Grant memory g = grants[id];
        if (block.timestamp <= g.start) return 0;
        if (block.timestamp >= g.end) return g.amount;
        return g.amount * (block.timestamp - g.start) / (g.end - g.start);
    }

    function withdraw(uint256 id) external {
        _withdraw(id, msg.sender, msg.sender);
    }

    function withdrawTo(uint256 id, address to, bytes calldata sig) external {
        bytes32 h = keccak256(abi.encodePacked("Withdraw to ", to));
        _withdraw(id, ECDSA.recover(h, sig), to);
    }

    function _withdraw(uint256 id, address signer, address to) internal {
        Grant storage g = grants[id];
        require(signer == g.grantee && block.timestamp <= g.end);
        uint256 amount = unlocked(id) - g.withdrawn;
        g.withdrawn += amount;
        token.safeTransfer(to, amount);
    }
}
