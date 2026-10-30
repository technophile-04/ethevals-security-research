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

contract Desk is EIP712 {
    struct Transfer { address token; uint256 amount; }
    struct Fee { address recipient; uint256 bps; }
    struct Order { address maker; Transfer pay; Fee fee; uint256 nonce; }
    bytes32 constant TRANSFER_TYPEHASH = keccak256("Transfer(address token,uint256 amount)");
    bytes32 constant FEE_TYPEHASH = keccak256("Fee(address recipient,uint256 bps)");
    bytes32 immutable ORDER_TYPEHASH;
    constructor(string memory orderType) EIP712("Desk", "1") { ORDER_TYPEHASH = keccak256(bytes(orderType)); }
    function digest(Order calldata o) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(ORDER_TYPEHASH, o.maker,
            keccak256(abi.encode(TRANSFER_TYPEHASH, o.pay.token, o.pay.amount)),
            keccak256(abi.encode(FEE_TYPEHASH, o.fee.recipient, o.fee.bps)), o.nonce)));
    }
    function verify(Order calldata o, bytes calldata sig) external view returns (bool) { return ECDSA.recover(digest(o), sig) == o.maker; }
}

contract Proof {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    string constant AS_WRITTEN = "Order(address maker,Transfer pay,Fee fee,uint256 nonce)Transfer(address token,uint256 amount)Fee(address recipient,uint256 bps)";
    string constant SORTED = "Order(address maker,Transfer pay,Fee fee,uint256 nonce)Fee(address recipient,uint256 bps)Transfer(address token,uint256 amount)";
    function testWalletSignatureRejected() public { _run(AS_WRITTEN, false); }
    function testControlSortedTypesAccepted() public { _run(SORTED, true); }
    function _run(string memory orderType, bool expectAccepted) internal {
        Desk d = new Desk(orderType); uint256 pk = 0xA11CE; address maker = vm.addr(pk);
        Desk.Order memory o = Desk.Order(maker, Desk.Transfer(address(0xA0b8), 1000), Desk.Fee(address(0xFEE), 30), 1);
        string memory json = string.concat(
            '{"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],',
            '"Order":[{"name":"maker","type":"address"},{"name":"pay","type":"Transfer"},{"name":"fee","type":"Fee"},{"name":"nonce","type":"uint256"}],',
            '"Transfer":[{"name":"token","type":"address"},{"name":"amount","type":"uint256"}],"Fee":[{"name":"recipient","type":"address"},{"name":"bps","type":"uint256"}]},',
            '"primaryType":"Order","domain":{"name":"Desk","version":"1","chainId":', vm.toString(block.chainid), ',"verifyingContract":"', vm.toString(address(d)), '"},',
            '"message":{"maker":"', vm.toString(maker), '","pay":{"token":"', vm.toString(address(0xA0b8)), '","amount":"1000"},"fee":{"recipient":"', vm.toString(address(0xFEE)), '","bps":"30"},"nonce":"1"}}');
        bytes32 walletDigest = vm.eip712HashTypedData(json);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, walletDigest);
        require((walletDigest == d.digest(o)) == expectAccepted, "digest expectation");
        require(d.verify(o, abi.encodePacked(r, s, v)) == expectAccepted, "verify expectation");
    }
}
