// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {vm} from "lib/Vm.sol";
import {Market, PlainToken} from "../src/Market.sol";

contract Proof {
    Market m;
    PlainToken coll;
    PlainToken debt;
    address user = address(0xBEEF);

    function setUp() public {
        coll = new PlainToken("COL");
        debt = new PlainToken("MIM");
        m = new Market(coll, debt);
        debt.mint(address(m), 1_000_000e18);
    }

    // Control: a plain borrow with no collateral hits the health check.
    function testBorrowAloneReverts() public {
        uint8[] memory ops = new uint8[](1); ops[0] = 2;
        bytes[] memory args = new bytes[](1); args[0] = abi.encode(uint256(100_000e18));
        vm.prank(user);
        vm.expectRevert(bytes("unhealthy"));
        m.run(ops, args);
    }

    // Borrow, then any op the market does not handle: the empty _customOp returns a zeroed Flags,
    // which overwrites checkHealth, so the health check is skipped.
    function testBorrowThenUnknownOpSkipsHealthCheck() public {
        uint8[] memory ops = new uint8[](2); ops[0] = 2; ops[1] = 0;
        bytes[] memory args = new bytes[](2); args[0] = abi.encode(uint256(100_000e18)); args[1] = "";
        vm.prank(user);
        m.run(ops, args);
        require(m.collateralOf(user) == 0, "has collateral");
        require(debt.balanceOf(user) == 100_000e18, "no borrowed tokens");
        require(m.debtOf(user) == 100_000e18, "debt not recorded");
    }

    // An unknown op before the borrow does not help: the flag is set after it.
    function testUnknownOpBeforeBorrowStillChecked() public {
        uint8[] memory ops = new uint8[](2); ops[0] = 0; ops[1] = 2;
        bytes[] memory args = new bytes[](2); args[0] = ""; args[1] = abi.encode(uint256(100_000e18));
        vm.prank(user);
        vm.expectRevert(bytes("unhealthy"));
        m.run(ops, args);
    }
}
