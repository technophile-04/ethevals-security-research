pragma solidity 0.8.28;
import "../src/Model.sol";
import "decoy/Base.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Proof {
    function testDecoyZeroLogoDoesNotAffectSafePosition() external {
        Position z = new Position(address(0)); Position n = new Position(address(1));
        z.adjust(10); n.adjust(10);
        require(z.collateral()==190 && z.collateral()==n.collateral(), "logo changed assets");
        (bool ok,) = address(z).call(abi.encodeCall(z.liquidate,()));
        require(!ok && z.collateral()==190, "safe collateral lost");
    }
    function testRealWrongScaleAdmitsLiquidationPenalty() external {
        Position p = new Position(address(1)); p.adjust(90);
        require(p.nominalRatio()==1.1e20 && p.nominalRatio()/100<p.minimum(), "bad state not admitted");
        p.liquidate();
        require(p.collateral()==5 && p.debt()==0, "penalty missing");
        require(200-(90+p.collateral())-100==5, "wrong net loss");
    }
}
