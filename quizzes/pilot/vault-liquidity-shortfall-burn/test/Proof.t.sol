pragma solidity 0.8.28;
import "../src/Model.sol";
import "decoy/Base.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Token is ERC20 {
    constructor() ERC20("Cash", "C") {}
    function mint(address to, uint n) external { _mint(to,n); }
}
contract Holder {
    Vault public vault;
    uint public callbacks;
    constructor(IERC20 t) { vault = new Vault(t); }
    function run(uint n) external { vault.redeem(n); }
    fallback() external { callbacks++; vault.redeem(1); }
}
contract Proof {
    function testDecoyNoCallbackOrExtraPayout() external {
        Token t = new Token(); Holder h = new Holder(t); Reserve r = h.vault().reserve();
        t.mint(address(r),100); h.run(100);
        require(h.callbacks()==0 && t.balanceOf(address(h))==100, "callback or excess payout");
        require(h.vault().shares(address(h))==0 && t.balanceOf(address(r))==0, "accounting");
    }
    function testRealPartialPayoutDestroysRemainingClaim() external {
        Token t = new Token(); Holder h = new Holder(t); Reserve r = h.vault().reserve();
        t.mint(address(r),10); t.mint(address(0xCAFE),90); h.run(100);
        require(t.balanceOf(address(h))==10 && h.vault().shares(address(h))==0, "loss missing");
        require(t.balanceOf(address(0xCAFE))==90, "locked assets absent");
        (bool ok,) = address(h).call(abi.encodeCall(h.run,(90)));
        require(!ok, "claim survived");
    }
}
