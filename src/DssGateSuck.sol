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

interface VatLike {
    function live() external returns (uint256);
    function suck(address, address, uint256) external;
    function dai(address) external view returns (uint256);
    function move(address, address, uint256) external;
}

interface JoinLike {
    function join(address, uint256) external;
}

/**
 @title Gate Suck
 FEATURES
  * token approval style draw limit on vat.suck

 DEPLOYMENT
  * ideally, each gate contract should only be linked to a single integration
  * authorized integration can then request a dai amount from gate contract with a "suck" call

 DRAW LIMIT
  * a limit on the amount of dai that can an integration can draw with a vat.suck call
  * simple gate uses an approved total amount, similar to a token approval
  * integrations can access up to this dai amount in total
  * if they repay the dai they can "refill the approval amount" allowing for future draws.

 DAI FORMAT
  * integrates with dai balance on vat, which uses the dsmath rad number type- 45 decimal fixed-point number

 MISCELLANEOUS
  * does not execute vow.heal to ensure the dai draw amount from vat.suck is lower than the surplus buffer currently held in vow
  * vat, and vow addresses cannot be updated after deployment
*/
contract DssGateSuck {
    // --- Auth ---
    mapping (address => uint256) public wards;                                       // Addresses with admin authority
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    function rely(address _usr) external auth { wards[_usr] = 1; emit Rely(_usr); }  // Add admin
    function deny(address _usr) external auth { wards[_usr] = 0; emit Deny(_usr); }  // Remove admin
    modifier auth {
        require(wards[msg.sender] == 1, "DssGateSuck/not-authorized");
        _;
    }

    // --- Integration Access Control ---
    mapping (address => uint256) public can;
    event Hope(address usr);
    event Nope(address usr);
    function hope(address _a) external auth {
        require(_a != address(0), "DssGateSuck/cannot-hope-nothing");
        can[_a] = 1;
        emit Hope(_a);
    }
    function nope(address _a) external auth {
        can[_a] = 0;
        emit Nope(_a);
    }
    modifier wish { require(can[msg.sender] == 1, "DssGateSuck/bud-not-authorized"); _; }

    /// maker protocol vat
    address public immutable vat;
    /// maker protocol vow
    address public immutable vow;

    /// draw limit- total amount that can be drawn from vat.suck
    uint256 public max; // [rad]
    // amount drawn- amount currently drawn and not put back
    uint256 public fill;

    constructor(address vat_, address vow_) {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);

        vat = vat_; // set vat address
        vow = vow_; // set vow address
    }

    // --- Events ---
    event File(bytes32 indexed what, uint256 data);
    event Draw(address indexed dst, uint256 amount); // log upon draw

    // --- UTILS ---
    function _max(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? y : x;
    }

    // --- Draw Limits ---
    /// Update draw limit
    /// @dev Restricted to authorized governance addresses
    /// @dev Approved total can be updated to both a higher or lower value
    /// @param what what value are we updating
    /// @param data what are we updating it to
    function file(bytes32 what, uint256 data) external auth {
        if (what == "max") {
            max = data; // update approved total amount
            emit File(what, data);
        } else revert("DssGateSuck/file-not-recognized");
    }

    /// Suck to destination
    /// @dev Restricted to approved integration addresses
    /// @param dst who are you sucking to
    /// @param amt dai amount in rad
    function suck(address dst, uint256 amt) public wish {
        require(VatLike(vat).live() == 1, "DssGateSuck/vat-not-live");

        fill = fill + amt;
        require(max >= fill, "DssGateSuck/insufficient-allowance");

        VatLike(vat).suck(vow, dst, amt);
        emit Draw(dst, amt);
    }

    /// Suck to sender
    /// @dev Restricted to approved integration addresses (because it calls the public suck)
    /// @param amt dai amount in rad
    function suck(uint256 amt) external {
        suck(msg.sender, amt);
    }

    /// Repay dai (reverse suck)
    function give(uint256 amt) external {
        if (fill >= amt) {
            fill = fill - amt;
        } else {
            fill = 0;
        }

        VatLike(vat).move(msg.sender, vow, amt);
    }

    /// Recover ERC-20 Dai
    /// In case someone sends ERC-20 dai to this contract
    /// send it to the surplus buffer
    /// @param join the address of the Dai Join adapter
    /// @param amt the amount of ERC dai to join [wad]
    function recover(address join, uint256 amt) external {
        if (fill >= amt) {
            fill = fill - amt * 10 ** 27;
        } else {
            fill = 0;
        }

        JoinLike(join).join(vow, amt);
    }
}
