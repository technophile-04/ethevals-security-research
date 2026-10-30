pragma solidity 0.8.28;
import "../src/Model.sol";
import "decoy/Base.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract RejectDeposit {
    function balance(address) external pure returns(uint) { return 0; }
    function deposit() external payable { revert(); }
}
contract Proof is Base {
    function testDecoyCallCreditsExactlyAndFailureRollsBack() external {
        vm.deal(address(this),100); Vault v = new Vault();
        vm.store(address(v),bytes32(uint(2)),bytes32(uint(1e18))); v.deposit{value:100}();
        require(v.receipt().balance(address(v))==100 && address(v.receipt()).balance==100, "deposit lost");
        require(v.shares(address(this))==50 && 300*50/v.supply()==100, "control lost value");
        uint supplyBefore = v.supply();
        vm.etch(address(v.receipt()),address(new RejectDeposit()).code);
        vm.deal(address(this),100);
        (bool ok,) = address(v).call{value:100}(abi.encodeCall(v.deposit,()));
        require(!ok && address(this).balance==100 && v.supply()==supplyBefore, "failure retained funds");
    }
    function testRealDuplicateConversionUndercreditsDepositor() external {
        vm.deal(address(this),100); Vault v = new Vault();
        require(v.assets()==400, "bad valuation missing"); v.deposit{value:100}();
        require(v.shares(address(this))==25 && v.supply()==125, "wrong minted shares");
        uint actualAssets = 200 + v.receipt().balance(address(v));
        require(v.shares(address(this))*actualAssets/v.supply()==60, "economic loss missing");
    }
}
