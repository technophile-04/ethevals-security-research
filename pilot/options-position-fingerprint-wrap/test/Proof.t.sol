// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract Model {
    mapping(uint256 => int256) public margin;
    bytes32 public stored;
    constructor() {
        margin[7] = 10; margin[19] = -20;
        stored = bytes32((uint256(2) << 248)
            | uint248(uint256(keccak256(abi.encode(uint256(7)))))
            ^ uint248(uint256(keccak256(abi.encode(uint256(19))))));
    }
function healthy(uint256[] calldata ids)
    external view returns (bool) {
    uint8 count;
    uint248 fingerprint;
    int256 net = -120;
    unchecked {
        for (uint256 i; i < ids.length; ++i) {
            ++count;
            fingerprint ^= uint248(uint256(keccak256(abi.encode(ids[i]))));
            net += margin[ids[i]];
        }
    }
    require(bytes32((uint256(count) << 248) | fingerprint) == stored);
    return net >= 0;
}
}
contract Proof {
    function positions(uint256 extra) internal pure returns (uint256[] memory ids) {
        ids = new uint256[](2 + extra); ids[0] = 7; ids[1] = 19;
        for (uint256 i = 2; i < ids.length; ++i) ids[i] = 7;
    }
    function testActualPositionsAreInsolvent() external {
        Model m = new Model(); require(!m.healthy(positions(0)), "actual list healthy");
    }
    function test256CopiesPreserveCommitmentAndInflateMargin() external {
        Model m = new Model(); require(m.healthy(positions(256)), "duplicates rejected");
    }
    function testTwoCopiesFailCountCheck() external {
        Model m = new Model();
        (bool ok,) = address(m).call(abi.encodeCall(m.healthy, (positions(2))));
        require(!ok, "count did not distinguish two extra entries");
    }
}
