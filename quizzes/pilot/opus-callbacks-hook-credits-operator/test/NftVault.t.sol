// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Proof} from "proof/Vm.sol";
import {NftVault} from "../src/NftVault.sol";

// Unmodified OpenZeppelin 5.4.0 ERC721; mint is exposed for the setup only.
contract Collection is ERC721("Collection", "COL") {
    function mint(address to, uint256 id) external { _mint(to, id); }
}

// A depositor contract that tries to re-enter on every hook it could receive.
contract Reenterer {
    NftVault public vault;
    Collection public nft;
    uint256 public hookCalls;
    uint256 public fallbackCalls;
    constructor(NftVault v, Collection n) { vault = v; nft = n; }
    function deposit(uint256 id) external { nft.safeTransferFrom(address(this), address(vault), id); }
    function withdraw(uint256 id) external { vault.withdraw(id); }
    function onERC721Received(address, address, uint256 id, bytes calldata) external returns (bytes4) {
        hookCalls++;
        try vault.withdraw(id) {} catch {}
        try vault.withdraw(id + 1) {} catch {}
        return this.onERC721Received.selector;
    }
    fallback() external payable { fallbackCalls++; try vault.withdraw(2) {} catch {} }
}

contract NftVaultProof is Proof {
    Collection nft;
    NftVault vault;
    address alice = address(0xA11CE);
    address helper = address(0x4E1);   // an operator Alice approved for all her NFTs

    function setUp() public {
        nft = new Collection();
        vault = new NftVault(IERC721(address(nft)));
    }

    // Decoy: withdraw calls out before deleting the record, but ERC721.transferFrom never
    // calls the receiver, so a contract depositor gets no chance to run code mid-withdraw.
    function test_decoy_transferFromBeforeDeleteCannotReenter() public {
        Reenterer r = new Reenterer(vault, nft);
        nft.mint(address(r), 1);
        nft.mint(alice, 2);
        r.deposit(1);
        vm.prank(alice);
        nft.safeTransferFrom(alice, address(vault), 2);
        assertEq(vault.depositor(1), address(r), "contract depositor credited");
        assertEq(vault.depositor(2), alice, "alice credited");

        r.withdraw(1);
        assertEq(r.hookCalls(), 0, "transferFrom called the receiver hook");
        assertEq(r.fallbackCalls(), 0, "transferFrom called the receiver");
        assertEq(nft.ownerOf(1), address(r), "own NFT returned");
        assertEq(vault.depositor(1), address(0), "record cleared");
        assertEq(nft.ownerOf(2), address(vault), "alice's NFT still in the vault");
        vm.expectRevert(bytes("not yours"));
        r.withdraw(1);
    }

    // Real cause: the hook's first argument is the operator (the caller of safeTransferFrom),
    // not the previous owner, so a deposit made by an approved helper is credited to the helper.
    function test_loss_hookCreditsOperatorNotOwner() public {
        nft.mint(alice, 7);
        vm.prank(alice);
        nft.setApprovalForAll(helper, true);
        vm.prank(helper);
        nft.safeTransferFrom(alice, address(vault), 7);

        assertEq(vault.depositor(7), helper, "credited to the operator");
        vm.prank(alice);
        vm.expectRevert(bytes("not yours"));
        vault.withdraw(7);

        vm.prank(helper);
        vault.withdraw(7);
        assertEq(nft.ownerOf(7), helper, "alice's NFT left to the helper");
    }
}
