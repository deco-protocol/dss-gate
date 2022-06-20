// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "../src/gate1.sol";

contract TestIntegration {
    Gate1 public gate;

    constructor(Gate1 gate_) {
        gate = gate_;
    }

    function draw(uint256 amount_) public {
        gate.draw(amount_);
    }

    function suck(address u, address v, uint256 rad) public {
        gate.suck(u, v, rad);
    }
}