// This should be a series of IAM/Mom modules that allow for reseting the
// Max Draw Dai in a gate based on custom/specific rules
// We could have one that holds a balance and acts like a allocated surplus buffer
// We could have one that just increases the allotment after a period of time
// We could have one that effectively streams allowance like DSS Vest



// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Copyright (C) 2022 Vamsi Alluri
// Copyright (C) 2022 Dai Foundation
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
pragma solidity 0.8.11;

interface GateLike {
    function file(bytes32, uint256) external;
}

/**
 @title Gate 1 "Simple Gate"
 @author Vamsi Alluri
 FEATURES
  * token approval style draw limit on vat.suck
  * backup dai balance in case vat.suck fails
  * access priority- try vat.suck first, backup balance second
  * no hybrid draw at one time from both vat.suck and backup balance

 DEPLOYMENT
  * ideally, each gate contract should only be linked to a single integration
  * authorized integration can then request a dai amount from gate contract with a "draw" call

 DRAW LIMIT
  * a limit on the amount of dai that can an integration can draw with a vat.suck call
  * simple gate uses an approved total amount, similar to a token approval
  * integrations can access up to this dai amount in total

 BACKUP BALANCE
  * gate can hold a backup dai balance
  * allows integrations to draw dai when calls to vat.suck fail for any reason

 DRAW SOURCE SELECTION, ORDER
  * this gate will not draw from both sources(vat.suck, backup dai balance) in a single draw call
  * draw call forwarded to vat.suck first
  * and then backup balance is tried when vat.suck fails due to draw limit or if gate is not authorized by vat
  * unlike draw limits applied to a vat.suck call, no additional checks are done when backup balance is used as source for draw

 DAI FORMAT
  * integrates with dai balance on vat, which uses the dsmath rad number type- 45 decimal fixed-point number

 MISCELLANEOUS
  * does not execute vow.heal to ensure the dai draw amount from vat.suck is lower than the surplus buffer currently held in vow
  * does not check whether vat is live at deployment time
  * vat, and vow addresses cannot be updated after deployment
*/
contract DssGateMomTimeReset {
    // --- Auth ---
    mapping (address => uint256) public wards;                                       // Addresses with admin authority
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    function rely(address _usr) external auth { wards[_usr] = 1; emit Rely(_usr); }  // Add admin
    function deny(address _usr) external auth { wards[_usr] = 0; emit Deny(_usr); }  // Remove admin
    modifier auth {
        require(wards[msg.sender] == 1, "DssGateMomTimeReset/not-authorized");
        _;
    }

    /// draw limit- total amount that can be drawn from vat.suck
    uint256 public bit; // [rad]

    /// withdraw condition- timestamp after which anyone can increase the max dai of a gate
    uint256 public ttl; // [timestamp]

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- Events ---
    event File(bytes32 indexed what, uint256 data);
    event ResetMax(address indexed who, uint256 bit);

    // --- Admin ---
    /// File new values
    /// @dev Restricted to authorized governance addresses
    /// @param what which data should be changed
    /// @param data new number value
    function file(bytes32 what, uint256 data) external auth {
        if (what == "bit") bit = data;
        else if (what == "ttl") {
            require(data > ttl, "DssGateMomTimeReset/ttl-value-lower");

            ttl = data;
        }

        emit File(what, data);
    }

    // --- Exec ---
    /// Updates the gate's authorization to pull funds
    /// reverts if not enough time has passed
    function exec(address who) external {
        require(ttl > 0, "DssGateMomTimeReset/not-active");
        require(block.timestamp >= ttl, "DssGateMomTimeReset/too-soon");

        ttl = 0; // Reset ttl so this can't be called multiple times
        GateLike(who).file("max", bit);

        emit ResetMax(who, bit);
    }
}
