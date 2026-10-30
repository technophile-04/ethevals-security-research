pragma solidity 0.8.28;
import "../src/Model.sol";
import "decoy/Base.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Proof is Base {
    function testDecoyFixedWidthEncodingRoundTrips(address m, int24 lo, int24 hi) external pure {
        bytes memory packed = abi.encodePacked(m,lo,hi);
        address recovered; int24 lower; int24 upper;
        assembly {
            recovered := shr(96,mload(add(packed,32)))
            lower := signextend(2,shr(232,mload(add(packed,52))))
            upper := signextend(2,shr(232,mload(add(packed,55))))
        }
        require(packed.length==26 && recovered==m && lower==lo && upper==hi, "ambiguous encoding");
    }
    function testDecoySeparateRangePreservesDepositValue() external {
        vm.deal(address(this),400); Pool p = new Pool(); address m = address(0x1234);
        p.add{value:100}(m,-40,40); p.add{value:200}(m,-41,40);
        Vault v = new Vault(p,m); v.deposit{value:100}();
        require(v.shares(address(this))==100 && v.supply()==200, "unrelated key changed price");
    }
    function testRealForeignLiquidityUndercreditsDepositor() external {
        vm.deal(address(this),400); Pool p = new Pool(); address m = address(0x1234);
        p.add{value:100}(m,-40,40); p.add{value:200}(m,-40,40);
        Vault v = new Vault(p,m); v.deposit{value:100}();
        uint minted = v.shares(address(this));
        require(minted==33 && v.supply()==133, "wrong minted shares");
        uint actualVaultAssets = 200;
        require(minted*actualVaultAssets/v.supply()==49, "economic loss missing");
    }
}
