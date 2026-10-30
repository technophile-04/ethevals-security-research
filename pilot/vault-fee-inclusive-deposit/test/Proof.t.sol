// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "oz/token/ERC20/ERC20.sol";
import "oz/token/ERC20/extensions/ERC4626.sol";
contract Token is ERC20 {constructor() ERC20("Asset","A") {} function mint(address to,uint256 n) external {_mint(to,n);}}
contract FeeVault is ERC4626 {
 constructor(IERC20 token) ERC20("Vault","V") ERC4626(token) {}
 function seed(address who) external {_mint(who,1499);}
 function previewDeposit(uint256 assets) public view override returns(uint256) {
  uint256 fee=Math.mulDiv(assets,37,10000+37,Math.Rounding.Up);
  return super.previewDeposit(assets-fee);
 }
 function _deposit(address caller,address receiver,uint256 assets,uint256 shares) internal override {
  uint256 fee=Math.mulDiv(assets,37,10000+37,Math.Rounding.Up);
  super._deposit(caller,receiver,assets,shares);
  IERC20(asset()).transfer(address(0xFEE),fee);
 }
}
contract Proof {
 function testFeeInclusiveDepositMints14975Shares() public {
  Token t=new Token();FeeVault v=new FeeVault(t);v.seed(address(0xB0B));t.mint(address(v),997);
  t.mint(address(this),10001);t.approve(address(v),10001);
  require(v.previewDeposit(10001)==14975,"preview");
  require(v.deposit(10001,address(this))==14975,"deposit");
  require(v.balanceOf(address(this))==14975&&t.balanceOf(address(0xFEE))==37,"balances");
 }
}

