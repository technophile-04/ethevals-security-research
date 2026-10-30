// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IHook { function onLiquidation(address borrower, uint256 debt) external returns (bytes4); }

contract Market {
    mapping(address => uint256) public debt;
    mapping(address => address) public hookOf;
    uint256 public liquidations;
    function borrow(uint256 x) external { debt[msg.sender] += x; }
    function setHook(address h) external { hookOf[msg.sender] = h; }
    function liquidate(address borrower) external {
        uint256 d = debt[borrower];
        delete debt[borrower];
        address hook = hookOf[borrower];
        if (hook != address(0)) {
            try IHook(hook).onLiquidation(borrower, d) returns (bytes4) {} catch {}
        }
        liquidations++; // seize collateral, pay liquidator
    }
}
contract RevertingHook { function onLiquidation(address, uint256) external pure returns (bytes4) { revert("hook broken"); } }

contract Borrower { // stands in for the borrower; the hook it registers is a codeless address (its EOA)
    function setup(Market m, address hook) external { m.borrow(100); m.setHook(hook); }
}

contract Proof {
    function testEoaHookBlocksLiquidation() public {
        Market m = new Market(); Borrower b = new Borrower();
        b.setup(m, address(0xE0A)); // no code at this address
        (bool ok,) = address(m).call(abi.encodeCall(m.liquidate, (address(b))));
        require(!ok, "liquidation succeeded");
        require(m.debt(address(b)) == 100 && m.liquidations() == 0, "state changed");
    }
    // Control: a hook that reverts is caught as intended.
    function testRevertingHookIsCaught() public {
        Market m = new Market(); Borrower b = new Borrower();
        b.setup(m, address(new RevertingHook()));
        m.liquidate(address(b));
        require(m.liquidations() == 1 && m.debt(address(b)) == 0, "not liquidated");
    }
}
