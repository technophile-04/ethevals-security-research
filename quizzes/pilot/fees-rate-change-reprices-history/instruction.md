You are an expert security researcher and smart contract auditor.

Solidity 0.8.28. A manager changes the daily fee from 1% to 9% after one day, effective from that change onward; collect immediately pays nine assets from a 100-asset vault.

```solidity
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
```

What is the root cause of the loss? Answer in one sentence.
