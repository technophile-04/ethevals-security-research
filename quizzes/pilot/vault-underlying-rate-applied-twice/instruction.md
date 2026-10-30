You are an expert security researcher and smart contract auditor.

Solidity 0.8.28. Receipt credits wei 1:1. The vault's 100 shares own 100 LP units worth two wei each; lpToAsset quotes underlying assets. Depositing 100 wei returns 25 shares.

```solidity
pragma solidity 0.8.28;
contract Receipt {
    mapping(address => uint) public balance;
    function deposit() external payable { balance[msg.sender] += msg.value; }
}
contract Vault {
    Receipt public immutable receipt = new Receipt();
    uint public lp = 100;
    uint public lpToAsset = 2e18;
    uint public receiptToAsset = 2e18;
    uint public supply = 100;
    mapping(address => uint) public shares;
    function assets() public view returns (uint) {
        return lp * lpToAsset / 1e18 * receiptToAsset / 1e18;
    }
    function deposit() external payable {
        uint beforeBalance = receipt.balance(address(this));
        address(receipt).call{value: msg.value}(abi.encodeCall(Receipt.deposit, ()));
        require(receipt.balance(address(this)) - beforeBalance == msg.value);
        uint n = msg.value * supply / assets();
        shares[msg.sender] += n; supply += n;
    }
}
```

What is the root cause of the loss? Answer in one sentence.
