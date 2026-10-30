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
