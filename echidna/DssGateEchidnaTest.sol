// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "../src/gate1.sol";
import "./DsMath.sol";
import "./Vm.sol";
import "./MockVow.sol";
import "./TestVat.sol";
import "./TestGovUser.sol";

import "./TestIntegration.sol";

contract DssGateEchidnaTest is DSMath {

    Vm public vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address public vow_addr;
    address public me;

    TestVat public vat;
    Gate1 public gate;
    MockVow public vow;
    TestGovUser public govUser;

    constructor() {
        vm.warp(1641400537);
        me = address(this);

        vat = new TestVat();
        vow = new MockVow(address(vat));
        gate = new Gate1(address(vow));
        govUser = new TestGovUser(gate);

        vat.rely(address(gate)); // vat rely gate
        gate.rely(address(govUser)); // gate rely gov

    }

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

    function test_daiBalance(uint256 amount) public {

        uint256 preBalance = gate.daiBalance();
        vat.mint(address(gate), rad(amount));
        assert (preBalance + rad(amount) == gate.daiBalance());
    }

    function test_maxDrawAmount() public view {
        assert( gate.maxDrawAmount() == max(gate.approvedTotal(), gate.daiBalance()));
    }

    function test_draw(uint256 amount) public {

        uint256 preBalanceInteg = vat.dai(msg.sender);
        uint256 backupBalance = vat.dai(address(gate));
        uint256 preApprovedTotal = gate.approvedTotal();

        try gate.draw(rad(amount)) {

            // Sender (dest) receives DAI
            assert(preBalanceInteg + rad(amount) == vat.dai(msg.sender));

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

    function test_withdrawdai(address dest, uint256 amount) public {

        uint256 preDestBal = vat.dai(dest);
        try govUser.withdrawDai(dest, amount) {
            assert(vat.dai(dest) == preDestBal + amount);
        }catch Error(string memory error_message) {
            assert(
                gate.wards(msg.sender) == 0 && cmpStr(error_message, "gate1/not-authorized") ||
                gate.daiBalance() < amount && cmpStr(error_message, "gate/insufficient-dai-balance")
            );
        } catch {
            assert(false);
        }
    }

    function test_helper_vat_mint(uint256 amount) public {
        vat.mint(address(gate), rad(amount));
    }

    function test_helper_vat_shutdown() public {
        vat.shutdown();
    }

    function test_helper_file_approvedTotal(uint256 amount) public {
        govUser.file("approvedTotal", amount);
    }

    function test_helper_file_withdrawAfter(uint256 timeStamp) public {
        govUser.file("withdrawAfter", timeStamp);
    }

    function cmpStr(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function rad(uint256 amt_) public pure returns (uint256) {
        return mulu(amt_, RAD);
    }
}
