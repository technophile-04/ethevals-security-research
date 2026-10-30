pragma solidity 0.8.28;
import "../src/Model.sol";
import "decoy/Base.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Proof is Base {
    receive() external payable {}
    function testDecoyExactClockAndRepeatedCollection() external {
        vm.deal(address(this),100 ether); Fees f = new Fees{value:100 ether}();
        vm.warp(block.timestamp+1 days); f.collect(); f.collect();
        require(address(f).balance==99 ether && address(this).balance==1 ether, "clock or repeat loss");
    }
    function testRealNewRateChargesOldDay() external {
        vm.deal(address(this),100 ether); Fees f = new Fees{value:100 ether}();
        vm.warp(block.timestamp+1 days); f.setRate(900); f.collect();
        require(address(f).balance==91 ether && address(this).balance==9 ether, "overcharge missing");
        require(99 ether-address(f).balance==8 ether, "wrong loss");
    }
}
