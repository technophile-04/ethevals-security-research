// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract Pool {
    address public token0;
    address public token1;
    constructor(address a, address b) { (token0, token1) = a < b ? (a, b) : (b, a); }
}
contract Quoter {
    function quote(address p, address input, address output, uint256 amount) external view returns (uint256) {
        Pool pool = Pool(p);
        require((input == pool.token0() && output == pool.token1())
            || (input == pool.token1() && output == pool.token0()));
        return amount;
    }
}
contract Router {
    function inputOf(uint256 descriptor) external view returns (address) {
        Pool p = Pool(address(uint160(descriptor)));
        return descriptor >> 255 == 1 ? p.token1() : p.token0();
    }
}
contract Model {
    address public wrapped;
    address public pool;
    Quoter public quoter;
    constructor(address w, address other) { wrapped = w; pool = address(new Pool(w, other)); quoter = new Quoter(); }
uint256 constant REVERSE = 1 << 255;
function route(address input, address output, uint256 amount)
    external view returns (uint256 descriptor, uint256 expected) {
    require(input == wrapped || output == wrapped);
    expected = quoter.quote(pool, input, output, amount);
    uint256 direction;
    if (input == wrapped) {
        direction = REVERSE;
    }
    descriptor = uint256(uint160(pool)) | direction;
}
}
contract Proof {
    function testWrappedAsToken0QuotesCorrectlyButEncodesWrongInput() external {
        Model m = new Model(address(0x100), address(0x200)); Router router = new Router();
        (uint256 descriptor, uint256 expected) = m.route(address(0x100), address(0x200), 80);
        require(expected == 80, "quote wrong");
        require(address(uint160(descriptor)) == m.pool(), "pool address overwritten");
        require(router.inputOf(descriptor) == address(0x200), "unexpected input direction");
    }
    function testWrappedAsToken1MatchesInput() external {
        Model m = new Model(address(0x300), address(0x200)); Router router = new Router();
        (uint256 descriptor,) = m.route(address(0x300), address(0x200), 80);
        require(router.inputOf(descriptor) == address(0x300), "control input wrong");
    }
    function testOtherInputAlsoReversesForWrappedAsToken0() external {
        Model m = new Model(address(0x100), address(0x200)); Router router = new Router();
        (uint256 descriptor,) = m.route(address(0x200), address(0x100), 80);
        require(router.inputOf(descriptor) == address(0x100), "reverse route unexpectedly correct");
    }
}
