// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Copyright (C) 2022 Deco Inc.,
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.8.0;

import "../src/gate1.sol";

import "./DsMath.sol";
import "./Vm.sol";
import "./MockVow.sol";
import "./TestVat.sol";
import "./TestGovUser.sol";
import "./TestIntegration.sol";

/**
@title Advanced Testing/Invariant Property Fuzzer for Dss-Gate.
@author Balaji Ramanarayan
@dev All the functions are compatible with Echidna 2.0+/ solc 0.8.

TESTING CONDUCT :

    * Every external function is exposed as a public test function.
    * Echidna Framework will simulate the call heirarchy by generating random sequences.
    * Echidna configuration is defined echidna.config.yml

 */
contract DssGateEchidnaTest is DSMath {

    address public vow_addr;
    address public me;
    address public integration_addr;

    Vm public vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    TestVat public vat;
    Gate1 public gate;
    MockVow public vow;
    TestGovUser public govUser;
    TestIntegration public integration;

    event MyMessage(string message);

    constructor() {
        vm.warp(1641400537);
        me = address(this);

        vat = new TestVat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        govUser = new TestGovUser(gate);
        integration = new TestIntegration(gate);

        integration_addr = address(integration);

        vat.rely(address(gate)); // vat rely gate
        gate.rely(address(govUser)); // gate rely gov

    }

    /*******************************************************/
    /***         Echidna Test Functions                  ***/
    /********************************************************/

    // --- Echidna Test : file(what, data) ---
    /// @param key Name of configurable params. (approvedTotal or withdrawAfter)
    /// @param value value for the params
    /// @dev Invariant : Only authorized wards can call file() function
    /// @dev Invariant : The value for 'withdrawafter' key should always be greater than existing value.
    function test_file(bytes32 key, uint256 value) public {

        try govUser.file(key, value) {
            if (key == "approvedtotal") {
                assert(gate.approvedTotal() == value);
            }
            if (key == "withdrawafter") {
                assert(gate.withdrawAfter() == value);
            }
        } catch Error(string memory error_message) {
            assert(
                gate.wards(msg.sender) == 0 && cmpStr(error_message, "gate1/not-authorized") ||
                (key != "approvedtotal" || key != "withdrawafter") && cmpStr(error_message, "gate/file-not-recognized") ||
                (key == "withdrawafter" && value <= gate.withdrawAfter()) && cmpStr(error_message, "withdrawAfter/value-lower")
            );
        } catch {
            assert(false);
        }
    }

    // --- Echidna Test : rely(usr) ---
    /// @param user An ward address. Upon rely, the user will be added to authorized ward list.
    /// @dev Invariant :
    /// @dev Access Invariant : Only authorized wards can call file() function
    function test_rely(address user) public {
        try gate.rely(user){
            assert(gate.wards(user) == 1);
        }catch Error (string memory error_message) {
            assert(
                gate.wards(msg.sender) == 0 && cmpStr(error_message, "gate1/not-authorized")
            );
        } catch {
            assert(false);
        }
    }

    // --- Echidna Test : kiss(integ) ---
    /// @param integ An integration to be authorized to suck from gate (via vat)
    /// @dev Invariant : The address of integration must be added to buds.
    /// @dev Invariant : An existing authorized ward can add a new integration
    /// @dev Invariant : address(0) cannot be added as integration
    /// @dev Invariant : Cannot add new integration after withdrawAfter is passed.
    function test_kiss(address integ) public {
        try govUser.kiss(integ) {
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

    // --- Echidna Test : diss(integ) ---
    /// @param integ An existing integration will be removed from gate authorized list.
    /// @dev Invariant : Verify the integration is removed from buds.
    /// @dev Access Invariant : An only existing authorized ward can remove
    function test_diss(address integ) public {

        try govUser.diss(integ) {
          assert(gate.bud(integ) == 0);
        } catch Error (string memory error_message) {
            assert(
                gate.wards(msg.sender) == 0 && cmpStr(error_message, "gate1/not-authorized") ||
                gate.bud(integ) == 0 && cmpStr(error_message, "bud/not-approved")
            );
        }
    }

    // --- Echidna Test : suck(integ) ---
    /// @param from Source address from which dai is drawn from vat
    /// @param to destination address to send the withdrawn dai
    /// @param amount dai amount in rad to suck
    /// @dev Invariant : only one source is used (either backup balance or approved total)
    /// @dev Invariant : If backup balance is modified, then dai balance of gate is reduced in VAT
    /// @dev Invariant : If approvedTotal is modified, then total approved limit is reduced for gate.
    /// @dev Access Invariant : Can be invoked by only authorized buds
    /// @dev Conditional Invariant : Amount to be withdrawn must be available in either of sources(backup or limit).
    /// @dev Conditional Invariant : The source address cannot be a genesis address (i.e 0x0)
    function test_suck(address from, address to, uint256 amount) public {

        govUser.kiss(address(integration)); // kiss integration
        uint256 backupBalance = vat.dai(address(gate));
        uint256 preApprovedTotal = gate.approvedTotal();

        try integration.suck(from, to, amount){

            // if backup balance is used
            if(backupBalance != vat.dai(address(gate))) {
                assert(backupBalance == vat.dai(address(gate)) + amount);
            }

            // if approved total is used
           else if ( preApprovedTotal != gate.approvedTotal()) {
                assert(preApprovedTotal == gate.approvedTotal() + amount);
            }

        } catch Error(string memory error_message) {
            assert(
                gate.bud(address(gate)) == 0 && cmpStr(error_message, "bud/not-authorized") ||
                gate.daiBalance() < amount && cmpStr(error_message, "gate/insufficient-dai-balance") ||
                from == address(0) && cmpStr(error_message, "bud/no-contract-0")
            );
        } catch {
            assert(false);
        }
    }

    // --- Echidna Test : maxDrawAmount() ---
    /// @dev Invariant : Returns the maximum permitted draw amount from all sources.
    function test_maxDrawAmount() public view {
        assert( gate.maxDrawAmount() == max(gate.approvedTotal(), gate.daiBalance()));
    }

    // --- Echidna Test : draw(amount) ---
    /// @param amount The amount in rad to be withdrawn by integration.
    /// @dev Invariant : An amount of dai will be transferred to integration.
    /// @dev Invariant : If backup balance is not used, approvedTotal is decreased by rad amount.
    /// @dev Invariant : If approvedTotal is not used, backupBalance is decreased by rad amount.
    /// @dev Access Invariant : Only authorized integrations are allowed to draw.
    /// @dev Conditional Invariant : The amount to be drawn must be available in either of sources.
    function test_draw(uint256 amount) public {

        govUser.kiss(integration_addr);
        uint256 backupBalance = vat.dai(address(gate));
        uint256 preApprovedTotal = gate.approvedTotal();

        try integration.draw(amount) {

            // backup balance unused when drawlimit is available
            if (backupBalance == vat.dai(address(gate))) {
                assert(gate.approvedTotal() == preApprovedTotal - amount);
            }

            // backup balance used when drawlimit not available
            if (gate.approvedTotal() == preApprovedTotal) {
                assert(backupBalance - amount == vat.dai(address(gate)));
            }

        } catch Error(string memory error_message) {
            assert(
                gate.bud(msg.sender) == 0 && cmpStr(error_message, "bud/not-authorized") ||
                gate.bud(address(gate)) == 0 && cmpStr(error_message, "bud/not-authorized") ||
                gate.daiBalance() < amount && cmpStr(error_message, "gate/insufficient-dai-balance")
            );
        } catch {
            assert(false);
        }
    }

    // --- Echidna Test  : withdrawdai(destination, amount) ---
    /// @param amount The amount in rad to be withdrawn by ward.
    /// @dev Invariant : The amount will be transferred from gate to destination in VAT.
    /// @dev Access Invariant : withdraw function can be invoked only by an authorized ward.
    /// @dev Condition Invariant : VAT must be live
    /// @dev Conditional Invariant : The amount to be drawn must be available in either of sources.
    function test_withdrawdai(uint256 amount) public {

        uint256 destBalance = vat.dai(address(govUser));

        try govUser.withdrawDai(address(govUser), amount) {
            assert(vat.dai(address(govUser)) == destBalance + amount);
        }catch Error(string memory error_message) {
            assert(
                gate.wards(msg.sender) == 0 && cmpStr(error_message, "gate1/not-authorized") ||
                gate.daiBalance() < amount && cmpStr(error_message, "gate/insufficient-dai-balance") ||
                block.timestamp < gate.withdrawAfter() && cmpStr(error_message, "withdraw-condition-not-satisfied")
            );
        } catch {
            assert(false);
        }
    }

    // ---  Test Helper : vat.mint(integ) ---
    /// @param amount The amount vat mints to gate.
    /// @dev Invariant : The dai assigned to gate should increase by rad amount in VAT.
    function test_daiBalance(uint256 amount) public {
        uint256 preBalance = gate.daiBalance();
        vat.mint(address(gate), amount);
        assert (preBalance + amount == gate.daiBalance());
    }

    // ---  Test Helper : vat.shutdown ---
    function test_helper_vat_shutdown() public {
        vat.shutdown();
    }

    // ---  Test Helper : vat.shutdown ---
   function test_helper_vat_mint(uint256 amount) public {
        vat.mint(address(gate), rad(amount));
    }

    // ---  Test Helper : gate.file(approvedTotal) ---
    function test_helper_file_approvedTotal(uint256 amount) public {
        govUser.file("approvedTotal", amount);
        assert(gate.approvedTotal() == amount);
    }

    // ---  Test Helper : gate.file(withdrawAfter) ---
    function test_helper_file_withdrawAfter(uint256 timeStamp) public {
        govUser.file("withdrawAfter", timeStamp);
        assert(gate.withdrawAfter() == timeStamp);
    }

    // ---  Test Helper : Comparision of in-memory strings ---
    function cmpStr(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }
}
