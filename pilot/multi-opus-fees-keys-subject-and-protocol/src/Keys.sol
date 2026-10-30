pragma solidity 0.8.28;
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract Keys {
    address public protocol = msg.sender;
    mapping(address => uint256) public supply;
    mapping(address => mapping(address => uint256)) public keys;

    function setProtocol(address p) external {
        protocol = p;
    }

    function price(uint256 s) public pure returns (uint256) {
        return s * s * 1e14;
    }

    function buy(address subject) external payable {
        uint256 s = supply[subject];
        require(s > 0 || msg.sender == subject, "subject buys first");
        uint256 p = price(s);
        require(msg.value == p + p / 10, "price");
        supply[subject] = s + 1;
        keys[subject][msg.sender] += 1;
        Address.sendValue(payable(protocol), p / 20);
        Address.sendValue(payable(subject), p / 20);
    }

    function sell(address subject) external {
        uint256 s = supply[subject] - 1;
        require(s > 0, "last key");
        supply[subject] = s;
        keys[subject][msg.sender] -= 1;
        uint256 p = price(s);
        Address.sendValue(payable(subject), p / 20);
        Address.sendValue(payable(msg.sender), p - p / 10);
    }
}
