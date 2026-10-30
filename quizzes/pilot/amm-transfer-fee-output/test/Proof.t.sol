// SPDX-License-Identifier: MIT
pragma solidity 0.5.16;
import "uni/contracts/UniswapV2Factory.sol";
import "uni/contracts/UniswapV2Pair.sol";
contract Token {
 mapping(address=>uint256) public balanceOf;
 uint256 public feeBps;
 function mint(address to,uint256 amount) external {balanceOf[to]+=amount;}
 function setFee(uint256 fee) external {feeBps=fee;}
 function transfer(address to,uint256 amount) external returns(bool) {
  require(balanceOf[msg.sender]>=amount,"balance");
  balanceOf[msg.sender]-=amount;
  balanceOf[to]+=amount-amount*feeBps/10000;return true;
 }
}
contract Fixture {
 function setup(bool feeOn) internal returns(UniswapV2Pair pair, Token t0,Token t1) {
  UniswapV2Factory f=new UniswapV2Factory(address(this));
  if(feeOn)f.setFeeTo(address(0xFEE));
  Token a=new Token();Token b=new Token();
  pair=UniswapV2Pair(f.createPair(address(a),address(b)));
  t0=Token(pair.token0());t1=Token(pair.token1());
 }
}
contract Proof is Fixture {
 function testLargestSuccessfulOutputIs9773() public {
  (UniswapV2Pair p,Token a,Token b)=setup(false);
  a.mint(address(p),1000000);b.mint(address(p),1000000);p.mint(address(this));
  a.setFee(100);a.mint(address(this),10000);a.transfer(address(p),10000);
  require(a.balanceOf(address(p))==1009900,"input fee");
  (bool tooMuch,)=address(p).call(abi.encodeWithSelector(p.swap.selector,uint256(0),uint256(9774),address(this),new bytes(0)));
  require(!tooMuch,"9774 accepted");
  p.swap(0,9773,address(this),new bytes(0));
  require(b.balanceOf(address(this))==9773,"output");
 }
}

