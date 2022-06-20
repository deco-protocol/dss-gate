// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "../src/gate1.sol";

contract TestGovUser {
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

    function file(bytes32 key, uint256 value) public {
        gate.file(key, value);
    }

    function withdrawDai(address dst_, uint256 amount_) public {
        gate.withdrawDai(dst_, amount_);
    }

}