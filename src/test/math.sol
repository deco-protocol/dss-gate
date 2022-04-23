// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
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

contract DSMath {
    uint256 constant internal WAD = 10 ** 18;
    uint256 constant internal RAY = 10 ** 27;
    uint256 constant internal RAD = 10 ** 45;

    function addu(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function subu(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    function mulu(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function addi(uint x, int y) internal pure returns (uint z) {
        z = x + uint(y);
        require(y >= 0 || z <= x);
        require(y <= 0 || z >= x);
    }

    function subi(uint x, int y) internal pure returns (uint z) {
        z = x - uint(y);
        require(y <= 0 || z <= x);
        require(y >= 0 || z >= x);
    }

    function muli(uint x, int y) internal pure returns (int z) {
        z = int(x) * y;
        require(int(x) >= 0);
        require(y == 0 || z / y == int(x));
    }

    function diff(uint x, uint y) internal pure returns (int z) {
        z = int(x) - int(y);
        require(int(x) >= 0 && int(y) >= 0);
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }

    function max(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? y : x;
    }

    function divup(uint x, uint y) internal pure returns (uint z) {
        // always rounds up
        z = addu(x, subu(y, 1)) / y;
    }

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = mulu(x, y) / WAD;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = mulu(x, WAD) / y;
    }

    function wdivup(uint x, uint y) internal pure returns (uint z) {
        // always rounds up
        z = addu(mulu(x, WAD), subu(y, 1)) / y;
    }

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mulu(x, y) / RAY;
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = mulu(x, RAY) / y;
    }

    function rdivup(uint x, uint y) internal pure returns (uint z) {
        // always rounds up
        z = addu(mulu(x, RAY), subu(y, 1)) / y;
    }

    function radmul(uint x, uint y) internal pure returns (uint z) {
        z = mulu(x, y) / RAD;
    }

    function radivup(uint x, uint y) internal pure returns (uint z) {
        // always rounds up
        z = addu(mulu(x, RAD), subu(y, 1)) / y;
    }

    function rpow(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0,0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0,0) }
                    x := div(xxRound, base)
                    if mod(n,2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0,0) }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }

    function either(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := or(x, y)}
    }

    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }
}
