// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract TokenStats {
    uint256 public totalSupply;
    uint256 private escrow;
    constructor(uint256 s, uint256 e) { totalSupply = s; escrow = e; }
    function balanceOf(address) external view returns (uint256) { return escrow; }
}
contract LockStats {
    uint256 public burnedPrincipal;
    constructor(uint256 retired) { burnedPrincipal = retired; }
    function bonus(uint256) external pure returns (uint256) { return 0; }
}
contract Model {
    TokenStats public token;
    LockStats public locks;
    address public locker = address(0x777);
    constructor(uint256 retired) { token = new TokenStats(900, 100); locks = new LockStats(retired); }
function rebase(uint256 issuance) external view returns (uint256) {
    uint256 supply = token.totalSupply();
    uint256 escrow = token.balanceOf(locker);
    uint256 retired = locks.burnedPrincipal();
    uint256 bonus = locks.bonus(retired);
    uint256 effectiveSupply = supply + bonus;
    uint256 locked = escrow + retired + bonus;
    uint256 circulating = effectiveSupply - locked;
    return (issuance * circulating / effectiveSupply)
        * circulating / (2 * effectiveSupply);
}
}
contract Proof {
    function testBurnedPrincipalUnderpaysWithoutRounding() external {
        Model m = new Model(200);
        require(m.rebase(16200) == 3600, "unexpected rebase");
        uint256 correct = (uint256(16200) * 800 / 900) * 800 / (2 * 900);
        require(correct == 6400 && m.rebase(16200) < correct, "underpayment absent");
        require(16200 * 600 % 900 == 0 && 10800 * 600 % 1800 == 0, "division loses precision");
    }
    function testNoBurnedPrincipalMatchesCirculatingSupply() external {
        Model m = new Model(0); require(m.rebase(16200) == 6400, "control differs");
    }
}
