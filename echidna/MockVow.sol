// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "./vat.sol";

contract MockVow {
    address public vat;
    constructor(address vat_) {
        vat = vat_;
    }
}