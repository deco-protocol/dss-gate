/* SPDX-License-Identifier: AGPL-3.0-or-later */
pragma solidity 0.8.11;

import "ds-test/test.sol";
// import "dss.git/vat.sol";
// import "./common/math.sol";
import "./DssGateSuck.sol";
// import "./test/Vm.sol";

contract MockVat {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth { require(live == 1, "Vat/not-live"); wards[usr] = 1; }
    function deny(address usr) external auth { require(live == 1, "Vat/not-live"); wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Vat/not-authorized");
        _;
    }

    mapping(address => mapping (address => uint)) public can;
    function hope(address usr) external { can[msg.sender][usr] = 1; }
    function nope(address usr) external { can[msg.sender][usr] = 0; }
    function wish(address bit, address usr) internal view returns (bool) {
        return either(bit == usr, can[bit][usr] == 1);
    }
    function either(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := or(x, y)}
    }

    mapping (address => uint256)                   public dai;  // [rad]
    mapping (address => uint256)                   public sin;  // [rad]

    uint256 public debt;  // Total Dai Issued    [rad]
    uint256 public vice;  // Total Unbacked Dai  [rad]
    uint256 public live;  // Active Flag

    constructor() {
        wards[msg.sender] = 1;
        live = 1;
    }

    function suck(address u, address v, uint rad) external auth {
        sin[u] = sin[u] + rad;
        dai[v] = dai[v] + rad;
        vice   = vice + rad;
        debt   = debt + rad;
    }

    function move(address src, address dst, uint256 rad) external {
        require(wish(src, msg.sender), "Vat/not-allowed");
        dai[src] = dai[src] - rad;
        dai[dst] = dai[dst] + rad;
    }

    function cage() external auth {
        live = 0;
    }
}

contract MockVow {
    constructor() {}
}

contract MockDaiJoin {
    MockVat immutable vat;
    uint constant ONE = 10 ** 27;

    constructor(address vat_) {
        vat = MockVat(vat_);
    }

    function join(address usr, uint256 wad) external {
        vat.move(address(this), usr, ONE * wad);
    }
}

contract Usr {
    DssGateSuck public gate;

    constructor(DssGateSuck gate_) {
        gate = gate_;
    }

    function suck(uint256 amount_) public {
        gate.suck(amount_);
    }

    function suck(address dst, uint256 rad) public {
        gate.suck(dst, rad);
    }
}

// // governance user
// contract Gov {
//     DssGateSuck public gate;

//     constructor(DssGateSuck gate_) {
//         gate = gate_;
//     }

//     function rely(address _usr) public {
//         gate.rely(_usr);
//     }

//     function deny(address _usr) public {
//         gate.deny(_usr);
//     }

//     function kiss(address _a) public {
//         gate.kiss(_a);
//     }

//     function diss(address _a) public {
//         gate.diss(_a);
//     }

//     function updateApprovedTotal(uint256 newTotal_) public {
//         gate.updateApprovedTotal(newTotal_);
//     }

//     function withdrawDai(address dst_, uint256 amount_) public {
//         gate.withdrawDai(dst_, amount_);
//     }

//     function updateWithdrawAfter(uint256 newWithdrawAfter) public {
//         gate.updateWithdrawAfter(newWithdrawAfter);
//     }
// }

contract DssGateSuckTest is DSTest {
    MockVat vat;
    address vow;
    DssGateSuck gate;

    uint256 constant internal WAD = 10 ** 18;
    uint256 constant internal RAD = 10 ** 45;

    function setUp() public {
        vat = new MockVat();
        vow = address(new MockVow());
        gate = new DssGateSuck(address(vat), address(vow));
        vat.rely(address(gate));
        gate.hope(address(this));
    }

    // should set gov vat and vow addresses
    function testAddresses() public {
        assertEq(gate.vat(), address(vat));
        assertEq(gate.vow(), address(vow));
    }

    function test_file_max() public {
        assertEq(gate.max(), 0);

        gate.file("max", 10 * RAD);

        assertEq(gate.max(), 10 * RAD);
    }

    function testFail_file_wrong_what() public {
        gate.file("wrong", 10);
    }

    function test_suck_to_self() public {
        gate.file("max", 10 * RAD);

        assertEq(vat.dai(address(this)), 0);
        assertEq(vat.vice(), 0);
        assertEq(vat.debt(), 0);
        assertEq(vat.sin(address(vow)), 0);
        assertEq(gate.fill(), 0);

        gate.suck(10 * RAD);

        assertEq(vat.dai(address(this)), 10 * RAD);
        assertEq(vat.vice(), 10 * RAD);
        assertEq(vat.debt(), 10 * RAD);
        assertEq(vat.sin(address(vow)), 10 * RAD);
        assertEq(gate.fill(), 10 * RAD);
    }

    function test_suck_to_other() public {
        gate.file("max", 10 * RAD);

        assertEq(vat.dai(address(this)), 0);
        assertEq(vat.dai(address(123)), 0);
        assertEq(vat.vice(), 0);
        assertEq(vat.debt(), 0);
        assertEq(vat.sin(address(vow)), 0);
        assertEq(gate.fill(), 0);

        gate.suck(address(123), 10 * RAD);

        assertEq(vat.dai(address(this)), 0);
        assertEq(vat.dai(address(123)), 10 * RAD);
        assertEq(vat.vice(), 10 * RAD);
        assertEq(vat.debt(), 10 * RAD);
        assertEq(vat.sin(address(vow)), 10 * RAD);
        assertEq(gate.fill(), 10 * RAD);
    }
    function testFail_suck_not_wished() public {
        gate.file("max", 10 * RAD);

        gate.nope(address(this));

        gate.suck(10 * RAD);
    }

    function testFail_vat_not_live() public {
        gate.file("max", 10 * RAD);

        vat.cage();

        gate.suck(10 * RAD);
    }

    function testFail_max_exceeded() public {
        gate.file("max", 10 * RAD);
        gate.suck(10 * RAD);

        gate.suck(10 * RAD);
    }

    function test_give_decreases_fill() public {
        gate.file("max", 10 * RAD);
        vat.hope(address(gate));

        assertEq(gate.fill(), 0);
        gate.suck(10 * RAD);

        assertEq(gate.fill(), 10 * RAD);
        assertEq(vat.dai(address(this)), 10 * RAD);
        assertEq(vat.dai(address(vow)), 0);

        gate.give(10 * RAD);

        assertEq(gate.fill(), 0);
        assertEq(vat.dai(address(this)), 0);
        assertEq(vat.dai(address(vow)), 10 * RAD);
    }

    function test_give_profit() public {
        vat.hope(address(gate));

        vat.suck(vow, address(this), 10 * RAD);
        assertEq(gate.fill(), 0);
        assertEq(vat.dai(address(this)), 10 * RAD);
        assertEq(vat.dai(address(vow)), 0);

        gate.give(10 * RAD);

        assertEq(gate.fill(), 0);
        assertEq(vat.dai(address(this)), 0);
        assertEq(vat.dai(address(vow)), 10 * RAD);
    }

    function test_recover_dai_decreases_fill() public {
        address mockJoin = address(new MockDaiJoin(address(vat)));
        vat.suck(vow, mockJoin, 10 * RAD);

        gate.file("max", 10 * RAD);
        gate.suck(10 * RAD);

        assertEq(gate.fill(), 10 * RAD);
        assertEq(vat.dai(address(vow)), 0);

        gate.recover(mockJoin, 10 * WAD);

        assertEq(gate.fill(), 0);
        assertEq(vat.dai(address(vow)), 10 * RAD);
    }

    function test_recover_dai_profit() public {
        address mockJoin = address(new MockDaiJoin(address(vat)));
        vat.suck(vow, mockJoin, 10 * RAD);

        assertEq(gate.fill(), 0);
        assertEq(vat.dai(address(vow)), 0);

        gate.recover(mockJoin, 10 * WAD);

        assertEq(gate.fill(), 0);
        assertEq(vat.dai(address(vow)), 10 * RAD);
    }
}
