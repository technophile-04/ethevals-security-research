pragma solidity 0.8.28;
contract Position {
    address public immutable manager;
    address public logo;
    uint public collateral = 200;
    uint public debt = 100;
    uint public minimum = 1.8e18;
    constructor(address image) { manager = msg.sender; logo = image; }
    function nominalRatio() public view returns (uint) {
        return collateral * 1e20 / debt;
    }
    function adjust(uint take) external {
        require(msg.sender == manager && take <= collateral);
        collateral -= take;
        require(nominalRatio() >= minimum);
    }
    function liquidate() external {
        require(collateral * 100 < debt * 120);
        collateral -= debt + 5;
        debt = 0;
    }
}
