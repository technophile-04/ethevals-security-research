// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Vm.sol";
import {Heroes} from "../src/Collateral.sol";

contract TestHeroes is Heroes {
    function mint(address to, uint256 id) external { _mint(to, id); }
    function setPledged(uint256 id, bool on) external { pledged[id] = on; }
}

// The same Collateral.sol compiled against OpenZeppelin 4.9.6: there the four-argument
// safeTransferFrom calls _safeTransfer directly, so the decoy would be a real hole.
contract ContrastProof is Proof {
    function test_contrast_oz496SafeTransferSkipsOverride() public {
        TestHeroes heroes = new TestHeroes();
        address borrower = address(0xB0);
        address buyer = address(0xB1);
        heroes.mint(borrower, 1);
        heroes.setPledged(1, true);
        vm.startPrank(borrower);
        vm.expectRevert(bytes("pledged"));
        heroes.transferFrom(borrower, buyer, 1);
        heroes.safeTransferFrom(borrower, buyer, 1, "");
        vm.stopPrank();
        assertEq(heroes.ownerOf(1), buyer, "pledged hero moved under 4.9.6");
    }
}
