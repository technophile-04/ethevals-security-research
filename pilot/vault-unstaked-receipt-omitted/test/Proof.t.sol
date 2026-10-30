pragma solidity 0.8.28;
import "../src/Model.sol";
import "decoy/Base.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Token is ERC20 {
    constructor() ERC20("Cash","C") {}
    function mint(address to,uint n) external { _mint(to,n); }
}
contract Proxy {
    address private immutable implementation;
    constructor(address target, address t, address b) {
        implementation = target;
        assembly { sstore(0,t) sstore(1,b) sstore(2,100) }
    }
    fallback() external {
        address target = implementation;
        assembly {
            calldatacopy(0,0,calldatasize())
            let ok := delegatecall(gas(),target,0,calldatasize(),0,0)
            returndatacopy(0,0,returndatasize())
            if iszero(ok) { revert(0,returndatasize()) }
            return(0,returndatasize())
        }
    }
}
contract Proof is Base {
    function deploy() internal returns (Token t, Booster b, Vault v) {
        t = new Token(); b = new Booster(); Vault impl = new Vault();
        v = Vault(address(new Proxy(address(impl),address(t),address(b)))); t.mint(address(v),101);
    }
    function testDecoySafeERC20WorksThroughProxy() external {
        (Token t, Booster b, Vault v) = deploy(); v.invest(100,true);
        require(v.assets()==101 && t.balanceOf(address(b))==100, "transfer or valuation loss");
        require(address(v.cash())==address(t) && address(v.booster())==address(b), "storage changed");
        t.mint(address(this),101); t.approve(address(v),101); v.deposit(101);
        require(v.shares(address(this))==100 && v.supply()==200, "unfair share claim");
    }
    function testRealUnstakedClaimMissingFromValuation() external {
        (Token t, Booster b, Vault v) = deploy(); v.invest(100,false);
        require(v.assets()==1 && b.receipts(address(v))==100, "omission missing");
        require(t.balanceOf(address(b))==100, "assets not backed");
        t.mint(address(this),1); t.approve(address(v),1); v.deposit(1);
        require(v.shares(address(this))==100 && v.supply()==200, "dilution missing");
        require(102*v.shares(address(this))/v.supply()==51, "economic loss missing");
    }
}
