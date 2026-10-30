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
 function testLiquidityMintIncludes58ProtocolShares() public {
  (UniswapV2Pair p,Token a,Token b)=setup(true);
  a.mint(address(p),1000000);b.mint(address(p),1000000);p.mint(address(this));
  require(p.kLast()==1000000000000&&p.totalSupply()==1000000,"initial state");
  a.mint(address(p),301);b.mint(address(p),409);p.sync();
  a.mint(address(p),16999);b.mint(address(p),17003);
  uint256 minted=p.mint(address(0xB0B));
  require(minted==16994,"entrant shares");
  require(p.balanceOf(address(0xFEE))==58,"protocol shares");
  require(p.totalSupply()==1017052,"supply");
 }
}

