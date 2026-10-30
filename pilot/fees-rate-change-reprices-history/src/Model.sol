pragma solidity 0.8.28;
contract Fees {
    address public immutable manager;
    uint public immutable principal;
    uint public rate = 100;
    uint public last;
    constructor() payable {
        manager = msg.sender; principal = msg.value;
        last = block.timestamp;
    }
    function setRate(uint next) external {
        require(msg.sender == manager && next <= 900);
        rate = next;
    }
    function collect() external {
        uint elapsed = block.timestamp - last;
        uint due = principal * rate * elapsed / 10000 / 1 days;
        last = block.timestamp;
        (bool ok,) = manager.call{value: due}("");
        require(ok);
    }
}
