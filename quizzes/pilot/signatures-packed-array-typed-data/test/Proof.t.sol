// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface Vm {
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
    function addr(uint256) external returns (address);
    function eip712HashTypedData(string calldata) external pure returns (bytes32);
    function toString(address) external pure returns (string memory);
    function toString(uint256) external pure returns (string memory);
}

contract Basket is EIP712 {
    struct Order { address maker; address[] tokens; uint256[] amounts; uint256 nonce; }
    bytes32 constant ORDER_TYPEHASH = keccak256("Order(address maker,address[] tokens,uint256[] amounts,uint256 nonce)");
    mapping(address => uint256) public filled;
    constructor() EIP712("Basket", "1") {}
    function digest(Order calldata o) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            ORDER_TYPEHASH, o.maker,
            keccak256(abi.encodePacked(o.tokens)),
            keccak256(abi.encodePacked(o.amounts)),
            o.nonce)));
    }
    function fill(Order calldata o, bytes calldata sig) external {
        require(ECDSA.recover(digest(o), sig) == o.maker, "bad signature");
        filled[o.maker] += 1;
    }
}

contract Proof {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 constant PK = 0xA11CE;

    function testWalletSignatureVerifies() public {
        Basket b = new Basket();
        address maker = vm.addr(PK);
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        Basket.Order memory o;
        o.maker = maker; o.tokens = new address[](2); o.tokens[0] = usdc; o.tokens[1] = weth;
        o.amounts = new uint256[](2); o.amounts[0] = 1000e6; o.amounts[1] = 1 ether; o.nonce = 7;
        // independent EIP-712 encoder (Foundry / alloy), as a wallet's eth_signTypedData_v4 would hash it
        string memory json = string.concat(
            '{"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],',
            '"Order":[{"name":"maker","type":"address"},{"name":"tokens","type":"address[]"},{"name":"amounts","type":"uint256[]"},{"name":"nonce","type":"uint256"}]},',
            '"primaryType":"Order","domain":{"name":"Basket","version":"1","chainId":', vm.toString(block.chainid), ',"verifyingContract":"', vm.toString(address(b)), '"},',
            '"message":{"maker":"', vm.toString(maker), '","tokens":["', vm.toString(usdc), '","', vm.toString(weth), '"],"amounts":["1000000000","1000000000000000000"],"nonce":"7"}}');
        bytes32 walletDigest = vm.eip712HashTypedData(json);
        require(walletDigest == b.digest(o), "contract digest differs from EIP-712");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK, walletDigest);
        b.fill(o, abi.encodePacked(r, s, v));
        require(b.filled(maker) == 1, "not filled");
    }
    // Control: hashing the tokens with abi.encode (offset + length + items) breaks the match.
    function testAbiEncodeOfArrayDiffers() public pure {
        address[] memory t = new address[](2); t[0] = address(1); t[1] = address(2);
        require(keccak256(abi.encodePacked(t)) == keccak256(abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(2)))), "packed array not word-padded");
        require(keccak256(abi.encode(t)) != keccak256(abi.encodePacked(t)), "abi.encode equal");
    }
}
