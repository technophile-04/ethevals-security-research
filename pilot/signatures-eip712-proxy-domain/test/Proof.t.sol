// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface Vm { function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32); function addr(uint256) external returns (address); }

contract Share is ERC20Permit {
    bool initialized;
    constructor(string memory n) ERC20(n, "lrVS") ERC20Permit(n) {}
    function initialize(address to) external { require(!initialized); initialized = true; _mint(to, 1000e18); }
}

contract Proof {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    uint256 constant PK = 0xA11CE;

    function _domain(string memory n, address vc) internal view returns (bytes32) {
        return keccak256(abi.encode(keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), keccak256(bytes(n)), keccak256("1"), block.chainid, vc));
    }
    function _deploy(string memory n) internal returns (Share s, address impl) {
        impl = address(new Share(n));
        s = Share(address(new ERC1967Proxy(impl, abi.encodeCall(Share.initialize, (vm.addr(PK))))));
    }
    function _permit(Share s, string memory signedName, address vc) internal returns (bool ok) {
        address owner = vm.addr(PK);
        bytes32 st = keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(this), 5e18, 0, block.timestamp + 1));
        (uint8 v, bytes32 r, bytes32 ss) = vm.sign(PK, keccak256(abi.encodePacked("\x19\x01", _domain(signedName, vc), st)));
        (ok,) = address(s).call(abi.encodeCall(s.permit, (owner, address(this), 5e18, block.timestamp + 1, v, r, ss)));
    }

    string constant LONG_NAME = "Liquid Restaked Ether Vault Share"; // 33 bytes

    // The quiz: a domain built from eip712Domain() read through the proxy is rejected.
    function testReportedDomainRejected() public {
        (Share s,) = _deploy(LONG_NAME);
        (, string memory reported, string memory version, uint256 chainId, address vc,,) = s.eip712Domain();
        require(bytes(reported).length == 0, "reported name not empty");
        require(keccak256(bytes(version)) == keccak256("1") && chainId == block.chainid && vc == address(s), "other fields");
        require(!_permit(s, reported, vc), "reported-domain permit accepted");
    }
    // Control: the same token accepts a domain with the full name, so only the reported name is wrong.
    function testFullNameAccepted() public {
        (Share s,) = _deploy(LONG_NAME);
        require(_permit(s, LONG_NAME, address(s)), "full-name permit rejected");
    }
    // Control: with a name of 31 bytes or less, eip712Domain() reports it correctly through the proxy.
    function testShortNameReportedCorrectly() public {
        (Share s,) = _deploy("Vault Share");
        (, string memory reported,,,,,) = s.eip712Domain();
        require(keccak256(bytes(reported)) == keccak256("Vault Share"), "short name wrong");
        require(_permit(s, reported, address(s)), "short reported-domain permit rejected");
        require(bytes(s.name()).length == 0, "ERC20 name() unexpectedly set in proxy storage");
    }
    // Control: deployed directly (no proxy), the long name is reported correctly.
    function testLongNameDirectDeployReportedCorrectly() public {
        Share direct = new Share(LONG_NAME);
        (, string memory reported,,,,,) = direct.eip712Domain();
        require(keccak256(bytes(reported)) == keccak256(bytes(LONG_NAME)), "direct name wrong");
    }
}
