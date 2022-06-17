// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;
import "./vat.sol";

contract TestVat is Vat {
    uint256 constant internal RAY = 10 ** 27;
    uint256 constant internal WAD = 10 ** 18;

    // constructor(){
    // }

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = (x * y) / RAY;
    }

    function ilkSetup(bytes32 ilk) public {
        this.init(ilk);
    }

    // increase rate by a percentage
    function increaseRate(bytes32 ilk_, uint256 percentage, address vow) public returns (uint256) {
        Ilk storage ilk = ilks[ilk_];

        // percentage between 0 to 500  in wad
        require(percentage >= 0 && percentage <= (500 * WAD), "not-valid-percentage");
        int256 rate = int256((ilk.rate * percentage)/10**20);

        ilk.rate = _add(ilk.rate, rate);
        int rad = _mul(ilk.Art, rate);
        dai[vow] = _add(dai[vow], rad);
        debt = _add(debt, rad);

        return ilk.rate;
    }

    function mint(address usr, uint rad) public {
        dai[usr] += rad;
        debt += rad;
    }
}
