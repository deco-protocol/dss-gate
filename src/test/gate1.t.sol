/* SPDX-License-Identifier: AGPL-3.0-or-later */
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "dss.git/vat.sol";
import "../gate1.sol";
import "./Vm.sol";
import "./math.sol";

contract TestVat is Vat {
    function mint(address usr, uint rad) public {
        dai[usr] += rad;
        debt += rad;
    }

    function try_cage() public {
        live = 0;
    }
}

contract MockVow {
    address public vat;

    constructor(address vat_) {
        vat = vat_;
    }
}

contract Integration {
    Gate1 public gate;

    constructor(Gate1 gate_) {
        gate = gate_;
    }

    function draw(uint256 amount_) public {
        gate.draw(amount_);
    }

    function suck(address u, address v, uint256 rad) public {
        gate.suck(u, v, rad);
    }
}

// governance user
contract Gov {
    Gate1 public gate;

    constructor(Gate1 gate_) {
        gate = gate_;
    }

    function rely(address _usr) public {
        gate.rely(_usr);
    }

    function deny(address _usr) public {
        gate.deny(_usr);
    }

    function kiss(address _a) public {
        gate.kiss(_a);
    }

    function diss(address _a) public {
        gate.diss(_a);
    }

    function updateApprovedTotal(uint256 newTotal_) public {
        gate.file("approvedtotal", newTotal_);
    }

    function withdrawDai(address dst_, uint256 amount_) public {
        gate.withdrawDai(dst_, amount_);
    }

    function updateWithdrawAfter(uint256 newWithdrawAfter) public {
        gate.file("withdrawafter", newWithdrawAfter);
    }
}

// when gate is deployed
contract DeployGate1Test is DSTest, DSMath {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    Vat vat;
    MockVow vow;
    Gate1 gate;
    address me;

    Gov public gov;
    address public gov_addr;

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }

    function setUp() public {
        vm.warp(1641400537);

        me = address(this);
        vat = new Vat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        vat.rely(address(gate));

        gov = new Gov(gate);
        gov_addr = address(gov);
        gate.rely(gov_addr);
        gate.deny(me);
    }

    // should set gov vat and vow addresses
    function testAddresses() public {
        assertTrue(gate.wards(gov_addr) == 1);
        assertTrue(gate.vat() != address(0));
        assertTrue(gate.vow() != address(0));
    }

    // should set withdrawafter to non-zero value
    function testWithdrawAfterNotZero() public {
        assertTrue(gate.withdrawAfter() != 0);
    }
}

// when integration is denied approval
contract IntegrationAuthDeniedGate1Test is DSTest, DSMath {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    Vat vat;
    MockVow vow;
    Gate1 gate;
    address me;

    Gov public gov;
    address public gov_addr;

    address user1;
    address user2;

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }

    function setUp() public {
        vm.warp(1641400537);

        me = address(this);
        vat = new Vat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        vat.rely(address(gate));

        gov = new Gov(gate);
        gov_addr = address(gov);
        gate.rely(gov_addr);
        gate.deny(me);

        user1 = address(new Integration(gate));
        gov.kiss(user1); // approve integration user1

        user2 = address(new Integration(gate));
    }

    // todo test expect emit event

    // should fail if integration is not already approved
    function testFailIntegrationNotApproved() public {
        // vm.expectRevert("bud/not-approved");
        gov.diss(user2);
    }

    // should pass if integration is approved
    function testIntegrationApproved() public {
        gov.diss(user1);
        assertEq(gate.bud(user1), 0);
    }

    // should fail if caller is not gov
    function testFailCallerNotGov() public {
        // vm.prank(address(1337)); // impersonate random address
        // vm.expectRevert("gate1/not-authorized");

        gate.diss(user1);
    }

    // should pass if caller is gov
    function testCallerGov() public {
        gov.diss(user1);
        assertEq(gate.bud(user1), 0);
    }
}

// when integration is approved
contract IntegrationAuthApprovedGate1Test is DSTest, DSMath {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    Vat vat;
    MockVow vow;
    Gate1 gate;
    address me;

    Gov public gov;
    address public gov_addr;

    address user1;
    address user2;

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }

    function setUp() public {
        vm.warp(1641400537);

        me = address(this);
        vat = new Vat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        vat.rely(address(gate));

        gov = new Gov(gate);
        gov_addr = address(gov);
        gate.rely(gov_addr);
        gate.deny(me);

        user1 = address(new Integration(gate));
        user2 = address(new Integration(gate));
    }

    // todo test expect emit event

    // should fail if integration was already approved
    function testFailIntegrationNotApproved() public {
        gov.kiss(user1);

        // vm.expectRevert("bud/approved");
        gov.kiss(user1);
    }

    // should pass if integration is not approved
    function testIntegrationApproved() public {
        gov.kiss(user1);
        assertEq(gate.bud(user1), 1);
    }

    // should fail if caller is not gov
    function testFailCallerNotGov() public {
        // vm.prank(address(1337)); // impersonate random address
        // vm.expectRevert("gate1/not-authorized");

        // unauthorized address
        gate.kiss(user1);
    }

    // should pass if caller is gov
    function testCallerGov() public {
        gov.kiss(user1);
        assertEq(gate.bud(user1), 1);
    }

    // should fail kiss if withdrawAfter is in the future
    function testFailWithdrawAfterFuture() public {
        gov.kiss(user1);
        assertEq(gate.bud(user1), 1);
        
        // move withdrawAfter to the future
        gov.updateWithdrawAfter(gate.withdrawAfter() + 60 seconds);

        gov.kiss(user2); // should fail
    }

    // should allow kiss if withdrawAfter is current
    function testWithdrawAfterCurrent() public {
        gov.kiss(user1);
        assertEq(gate.bud(user1), 1);
        
        // move withdrawAfter to the future
        gov.updateWithdrawAfter(gate.withdrawAfter() + 60 seconds);

        vm.warp(block.timestamp + 60 seconds);

        gov.kiss(user2); // should succeed
    }

    // should allow kiss if withdrawAfter is in the past
    function testWithdrawAfterPast() public {
        gov.kiss(user1);
        assertEq(gate.bud(user1), 1);
        
        // move withdrawAfter to the future
        gov.updateWithdrawAfter(gate.withdrawAfter() + 60 seconds);

        vm.warp(block.timestamp + 120 seconds);

        gov.kiss(user2); // should succeed
    }
}

// when dai balance is called
contract DaiBalanceGate1Test is DSTest, DSMath {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    TestVat vat;
    MockVow vow;
    Gate1 gate;
    address me;

    Gov public gov;
    address public gov_addr;

    address user1;
    address user2;

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }

    function setUp() public {
        vm.warp(1641400537);

        me = address(this);
        vat = new TestVat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        vat.rely(address(gate));

        gov = new Gov(gate);
        gov_addr = address(gov);
        gate.rely(gov_addr);
        gate.deny(me);

        user1 = address(new Integration(gate));
        user2 = address(new Integration(gate));

        vat.mint(address(this), rad(123));
    }

    // should return dai balance of gate in vat
    function testDaiBalance() public {
        // transfer dai to gate
        vat.move(address(this), address(gate), rad(100));

        // check if balance matches
        assertEq(gate.daiBalance(), rad(100));
    }
}

// when max draw amount is called
contract MaxDrawGate1Test is DSTest, DSMath {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    TestVat vat;
    MockVow vow;
    Gate1 gate;
    address me;

    Gov public gov;
    address public gov_addr;

    address user1;
    address user2;

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }

    function setUp() public {
        vm.warp(1641400537);

        me = address(this);
        vat = new TestVat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        vat.rely(address(gate));

        gov = new Gov(gate);
        gov_addr = address(gov);
        gate.rely(gov_addr);
        gate.deny(me);

        user1 = address(new Integration(gate));
        user2 = address(new Integration(gate));

        vat.mint(address(this), rad(123)); // mint dai
    }

    // should return approved total when it is higher
    function testReturnApprovedTotal() public {
        vat.move(address(this), address(gate), rad(100)); // add some backup balance
        gov.updateApprovedTotal(rad(150));// add a draw limit

        assertEq(gate.maxDrawAmount(), rad(150));
    }

    // should return backup balance when it is higher
    function testReturnBackupBalance() public {
        vat.move(address(this), address(gate), rad(100)); // add some backup balance
        gov.updateApprovedTotal(rad(75));// add a draw limit

        assertEq(gate.maxDrawAmount(), rad(100));
    }

    // should work even when gate is not authorized in vat
    function testUnauthorizedVat() public {
        vat.move(address(this), address(gate), rad(100)); // add some backup balance
        gov.updateApprovedTotal(rad(75));// add a draw limit

        vat.deny(address(gate));
        assertEq(gate.maxDrawAmount(), rad(100)); // works
    }

}

// when approved total is updated
contract ApprovedTotalUpdateGate1Test is DSTest, DSMath {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    TestVat vat;
    MockVow vow;
    Gate1 gate;
    address me;

    Gov public gov;
    address public gov_addr;

    address user1;
    address user2;

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }

    function setUp() public {
        vm.warp(1641400537);

        me = address(this);
        vat = new TestVat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        vat.rely(address(gate));

        gov = new Gov(gate);
        gov_addr = address(gov);
        gate.rely(gov_addr);
        gate.deny(me);

        user1 = address(new Integration(gate));
        user2 = address(new Integration(gate));

        vat.mint(address(this), rad(123)); // mint dai

        gov.updateApprovedTotal(rad(750)); // setup approved total
    }

    // should fail if address is not gov
    function testFailUpdateNewApprovedTotalNotGov() public {
        // vm.prank(address(1337)); // impersonate random address
        // vm.expectRevert("gate1/not-authorized");

        // unauthorized address
        gate.file("approvedtotal", rad(999));
    }

    // should succeed if address is gov
    function testUpdateNewApprovedTotalGov() public {
        gov.updateApprovedTotal(rad(999));
        assertEq(gate.approvedTotal(), rad(999));
    }

    // todo should emit a new approved total event

    // should update new total when it is lower
    function testUpdateNewApprovedTotalLower() public {
        gov.updateApprovedTotal(rad(500)); // change 750 to 500
        assertEq(gate.approvedTotal(), rad(500));
    }

    // should update new total when it is higher
    function testUpdateNewApprovedTotalHigher() public {
        gov.updateApprovedTotal(rad(1234)); // change 750 to 1234
        assertEq(gate.approvedTotal(), rad(1234));
    }
}

// when dai is drawn by integration
contract DaiDrawnGate1Test is DSTest, DSMath {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    TestVat vat;
    MockVow vow;
    Gate1 gate;
    address me;

    Gov public gov;
    address public gov_addr;

    Integration user1;
    Integration user2;

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }

    function setUp() public {
        vm.warp(1641400537);

        me = address(this);
        vat = new TestVat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        vat.rely(address(gate));

        gov = new Gov(gate);
        gov_addr = address(gov);
        gate.rely(gov_addr);
        gate.deny(me);

        user1 = new Integration(gate);
        gov.kiss(address(user1)); // authorize user1
        user2 = new Integration(gate);

        vat.mint(address(this), rad(123)); // mint dai
    }

    // draw fails if integration is not approved
    function testFailIntegrationNotApproved() public {
        // vm.expectRevert("bud/not-authorized");
        user2.draw(rad(1)); // user2 not authorized
    }

    // draw succeeds if integration is approved
    function testIntegrationApproved() public {
        vat.move(me, address(gate), rad(50)); // backup balance: 50
        user1.draw(rad(10)); // draw: 10
    }

    // draw succeeds without suck when backup balance is present
    function testBackupBalance() public {
        vat.deny(address(gate)); // no auth, force backup balance usage
        vat.move(me, address(gate), rad(50)); // backup balance: 50

        user1.draw(rad(10)); // draw: 10
        assertEq(vat.dai(address(gate)), rad(40));
    }

    // draw succeeds without suck when backup balance is present and vat is not live
    function testBackupBalanceVatNotLive() public {
        vat.deny(address(gate)); // no auth, force backup balance usage
        vat.move(me, address(gate), rad(50)); // backup balance: 50

        vat.try_cage(); // vat not live, force backup balance usage

        user1.draw(rad(10)); // draw: 10
        assertEq(vat.dai(address(gate)), rad(40));
    }

    // draw succeeds with suck when backup balance is present
    function testBackupBalanceZero() public {
        gov.updateApprovedTotal(rad(25)); // draw limit approved total: 25
        vat.move(me, address(gate), rad(50)); // backup balance: 50

        user1.draw(rad(10)); // draw from vat: 10
        assertEq(vat.dai(address(gate)), rad(50));  // draw from backup balance: 0
    }

    // draw fails when approved limit is lower than amount
    function testFailApprovedLimitLowerThanDraw() public {
        gov.updateApprovedTotal(rad(25)); // draw limit approved total: 25
        // backup balance: 0

        user1.draw(rad(50)); // draw from vat: 50
    }

    // draw fails when vat does not authorize gate
    function testFailVatNotAuthorized() public {
        vat.deny(address(gate)); // no vat auth
        gov.updateApprovedTotal(rad(25)); // draw limit approved total: 25
        // backup balance: 0

        user1.draw(rad(10)); // draw from vat: 10
    }

    // draw fails when backup balance is not sufficient
    function testFailInsufficientBackupBalance() public {
        vat.deny(address(gate)); // no vat auth
        vat.move(me, address(gate), rad(50)); // backup balance: 50

        user1.draw(rad(75)); // draw from vat: 75
    }

    // draw updates balance of integration and gate when backup balance is used
    function testBalancesUpdated() public {
        vat.deny(address(gate)); // no auth, force backup balance usage
        vat.move(me, address(gate), rad(50)); // backup balance: 50

        user1.draw(rad(10)); // draw: 10
        assertEq(vat.dai(address(gate)), rad(40)); // backup balance: 40
        assertEq(vat.dai(address(user1)), rad(10)); // integration : 10
    }

    // draw increases sin when suck is used
    function testIncreaseSinAfterSuck() public {
        // backup balance: 0
        gov.updateApprovedTotal(rad(50)); // draw limit approved total: 50

        user1.draw(rad(10)); // draw: 10
        assertEq(vat.sin(address(vow)), rad(10));
    }

    // todo draw emits the draw event

    // draw decreases the approved total when suck is used
    function testDecreaseApprovedTotalAfterSuck() public {
        // backup balance: 0
        gov.updateApprovedTotal(rad(50)); // draw limit approved total: 50

        user1.draw(rad(10)); // draw: 10
        assertEq(gate.approvedTotal(), rad(40));
    }

    // draw leaves approved total unchanged when backup balance is used
    function testApprovedTotalUnchanged() public {
        gov.updateApprovedTotal(rad(10)); // draw limit approved total: 10
        vat.move(me, address(gate), rad(50)); // backup balance: 50

        user1.draw(rad(25)); // draw: 25
        assertEq(gate.approvedTotal(), rad(10));  // approved total unchanged
        assertEq(vat.dai(address(gate)), rad(25)); // backup balance: 25
    }

    // gate suck interface fails when vat is not live
    function testFailGateSuckInterfaceVatNotLive() public {
        // backup balance: 0
        gov.updateApprovedTotal(rad(50)); // draw limit approved total: 50

        vat.try_cage(); // cages vat and sets live flag to 0

        user1.suck(address(0), address(user2), rad(10)); // draw: 10
    }

    // gate suck interface works when vat is live
    function testGateSuckInterface() public {
        // backup balance: 0
        gov.updateApprovedTotal(rad(50)); // draw limit approved total: 50

        assertEq(vat.live(), 1); // vat is live

        user1.suck(address(0), address(user2), rad(10)); // draw: 10
        assertEq(vat.dai(address(user2)), rad(10)); // user2: 10
    }

    // should test priority of sources
    function testSourcePriority() public {
        gov.updateApprovedTotal(rad(75)); // draw limit approved total: 75
        vat.move(me, address(gate), rad(50)); // backup balance: 50

        user1.draw(rad(25)); // draw: 25
        assertEq(gate.approvedTotal(), rad(50));  // approved total: 50
        assertEq(vat.dai(address(gate)), rad(50)); // backup balance: 50
    }

    // should draw from backup balance when amount is beyond draw limit
    function testDrawBackupBalanceExceedsApprovedTotal() public {
        gov.updateApprovedTotal(rad(10)); // draw limit approved total: 10
        vat.move(me, address(gate), rad(50)); // backup balance: 50

        user1.draw(rad(25)); // draw: 25
        assertEq(gate.approvedTotal(), rad(10));  // approved total unchanged
        assertEq(vat.dai(address(gate)), rad(25)); // backup balance: 25
    }

    // should draw from backup balance when amount is beyond draw limit and vat not live
    function testDrawBackupBalanceExceedsApprovedTotalVatNotLive() public {
        gov.updateApprovedTotal(rad(10)); // draw limit approved total: 10
        vat.move(me, address(gate), rad(50)); // backup balance: 50

        vat.try_cage();

        user1.draw(rad(25)); // draw: 25
        assertEq(gate.approvedTotal(), rad(10));  // approved total unchanged
        assertEq(vat.dai(address(gate)), rad(25)); // backup balance: 25
    }
}

// when dai is withdrawn by governance
contract DaiWithdrawnGate1Test is DSTest, DSMath {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    TestVat vat;
    MockVow vow;
    Gate1 gate;
    address me;

    Integration user1;
    Integration user2;
    
    Gov public gov;
    address public gov_addr;

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }

    function setUp() public {
        vm.warp(1641400537);

        me = address(this);
        vat = new TestVat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        vat.rely(address(gate));

        gov = new Gov(gate);
        gov_addr = address(gov);
        gate.rely(gov_addr);
        gate.deny(me);

        user1 = new Integration(gate);
        gov.kiss(address(user1)); // authorize user1
        user2 = new Integration(gate);

        vat.mint(me, rad(123)); // mint dai
        vat.move(me, address(gate), rad(75)); // backup balance: 75
    }

    // should fail if caller is not gov
    function testFailCallerNotGov() public {
        // vm.prank(address(1337)); // impersonate random address
        // vm.expectRevert("gate1/not-authorized");
        
        // unauthorized address
        gate.withdrawDai(me, rad(10));
    }

    // should fail if current timestamp is before withdraw after
    function testFailNowBeforeWithdrawAfter() public {
        gov.updateWithdrawAfter(1641500000);
        vm.warp(1641499900); // time before withdraw after

        // vm.expectRevert("withdraw-condition-not-satisfied");
        gov.withdrawDai(me, rad(10));
    }

    // should pass if caller is gov
    function testCallerIsGov() public {
        gov.updateWithdrawAfter(1641500000);
        vm.warp(1641500111); // time after withdraw after

        gov.withdrawDai(me, rad(10));
        assertEq(vat.dai(address(gate)), rad(65)); // backup balance: 65
    }

    // should pass if current timestamp is after withdraw after
    function testNowAfterWithdraw() public {
        gov.updateWithdrawAfter(1641500000);
        vm.warp(1641500111); // time after withdraw after

        gov.withdrawDai(me, rad(10));
        assertEq(vat.dai(address(gate)), rad(65)); // backup balance: 65
    }

    // should fail if sufficient balance is not present
    function testFailBalanceNotPresent() public {
        gov.updateWithdrawAfter(1641500000);
        vm.warp(1641500111); // time after withdraw after

        // vm.expectRevert("gate/insufficient-dai-balance");
        gov.withdrawDai(me, rad(100)); // backup balance: 75
    }

    // should adjust dai balances of gate and gov by amount
    function testDaiBalances() public {
        gov.updateWithdrawAfter(1641500000);
        vm.warp(1641500111); // time after withdraw after

        gov.withdrawDai(me, rad(10));
        assertEq(vat.dai(address(gate)), rad(65)); // backup balance: 65
        assertEq(vat.dai(me), rad(58)); // 123 - 75 + 10 = 58
    }

    // todo should emit a withdraw event
}

// when withdraw after timestamp is updated
contract WithdrawAfterUpdateGate1Test is DSTest, DSMath {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    TestVat vat;
    MockVow vow;
    Gate1 gate;
    address me;

    Integration user1;
    Integration user2;

    Gov public gov;
    address public gov_addr;

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }

    function setUp() public {
        vm.warp(1641400537);

        me = address(this);
        vat = new TestVat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        vat.rely(address(gate));

        gov = new Gov(gate);
        gov_addr = address(gov);
        gate.rely(gov_addr);
        gate.deny(me);

        user1 = new Integration(gate);
        gov.kiss(address(user1)); // authorize user1
        user2 = new Integration(gate);

        vat.mint(me, rad(123)); // mint dai
    }

    // should not be zero after deployment
    function testWithdrawAfterNotZero() public {
        assertGt(gate.withdrawAfter(), 0);
    }

    // should fail if caller is not gov
    function testFailCallerNotGov() public {
        // vm.prank(address(1337)); // impersonate random address
        // vm.expectRevert("gate1/not-authorized");
        
        // call from unauthorized address
        gate.file("withdrawafter", 1641500000);
    }

    // should pass if caller is gov
    function testCallerGov() public {
        gov.updateWithdrawAfter(1641500000);
        assertEq(gate.withdrawAfter(), 1641500000);
    }

    // should fail if new withdraw after time is lower than previous
    function testFailWithdrawAfterLower() public {
        gov.updateWithdrawAfter(1641500000);

        // vm.expectRevert("withdrawAfter/value-lower");
        gov.updateWithdrawAfter(1641400000);
    }

    // should set the input value when successful
    function testWithdrawAfter() public {
        gov.updateWithdrawAfter(1641500000);
        assertEq(gate.withdrawAfter(), 1641500000);
    }

    // todo should emit a new withdraw after event
}

