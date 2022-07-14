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

/**
    @title An authorized ward in gate, used for testing purposes only
    @author Balaji Ramanarayan
    @dev All the functions are compatible with Echidna 2.0+/ solc 0.8.
 */
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