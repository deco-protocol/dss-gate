// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "../src/gate1.sol";
import "./DsMath.sol";
import "./Vm.sol";
import "./MockVow.sol";
import "./TestVat.sol";


contract DssGateEchidnaTest  {

    Vm public vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address public vow_addr;
    address public me;

    TestVat public vat;
    Gate1 public gate;
    MockVow public vow;

    constructor() {
        vm.warp(1641400537);

        vat = new TestVat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        me = address(this);

    }

    function test_kiss(address integ) public {
        try gate.kiss(integ) {
            assert(gate.bud(integ) == 1);
        } catch Error (string memory error_message) {
            assert(
                gate.wards(msg.sender) == 0 && cmpStr(error_message, "gate1/not-authorized") ||
                gate.bud(integ) == 1 && cmpStr(error_message, "bud/approved") ||
                integ == address(0) && cmpStr(error_message, "bud/no-contract-0") ||
                block.timestamp < gate.withdrawAfter() && cmpStr(error_message, "withdraw-condition-not-satisfied")
            );
        } catch {
            assert(false);
        }
    }

    function test_diss(address integ) public {
        try gate.diss(integ) {
          assert(gate.bud(integ) == 0);
        } catch Error (string memory error_message) {
            assert(
                gate.wards(msg.sender) == 0 && cmpStr(error_message, "gate1/not-authorized") ||
                gate.bud(integ) == 0 && cmpStr(error_message, "bud/not-approved")
            );
        }
    }

    function cmpStr(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}
