// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Copyright (C) 2022 Vamsi Alluri
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

abstract contract VatAbstract {
    function live() external virtual view returns (uint256);
    function heal(uint256) external virtual;
    function suck(address, address, uint256) external virtual;
    function dai(address) external virtual view returns (uint256);
    function move(address, address, uint256) external virtual;
}

abstract contract VowAbstract {
    function vat() external virtual view returns (address);
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
  * does not check whether vat is live at deployment time
  * vat, and vow addresses cannot be updated after deployment
*/
contract Gate1 {
    // --- Auth ---
    mapping (address => uint256) public wards;                                       // Addresses with admin authority
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    function rely(address _usr) external auth { wards[_usr] = 1; emit Rely(_usr); }  // Add admin
    function deny(address _usr) external auth { wards[_usr] = 0; emit Deny(_usr); }  // Remove admin
    modifier auth {
        require(wards[msg.sender] == 1, "gate1/not-authorized");
        _;
    }

    // --- Integration Access Control ---
    mapping (address => uint256) public bud;
    event Kiss(address a);
    event Diss(address a);
    function kiss(address _a) external auth {
        require(_a != address(0), "bud/no-contract-0");
        require(bud[_a] == 0, "bud/approved");
        // stop new address addition when a guarantee is in place
        require(withdrawalConditionSatisfied(), "withdraw-condition-not-satisfied");

        bud[_a] = 1;
        emit Kiss(_a);
    }
    function diss(address _a) external auth {
        require(bud[_a] == 1, "bud/not-approved");
        bud[_a] = 0;
        emit Diss(_a);
    }
    modifier toll { require(bud[msg.sender] == 1, "bud/not-authorized"); _; }

    /// maker protocol vat
    address public immutable vat;
    /// maker protocol vow
    address public immutable vow;

    /// draw limit- total amount that can be drawn from vat.suck
    uint256 public approvedTotal; // [rad]

    /// withdraw condition- timestamp after which backup dai balance withdrawal is allowed
    uint256 public withdrawAfter; // [timestamp]

    constructor(address vow_) {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);

        vat = VowAbstract(vow_).vat(); // set vat address
        vow = vow_; // set vow address

        withdrawAfter = block.timestamp; // set withdrawAfter to now
        // governance should set withdrawAfter to a future timestamp after deployment
        // and loading a backup balance in gate to give the integration a guarantee
        // that the backup dai balance will not be prematurely withdrawn
    }

    // --- Events ---
    event NewApprovedTotal(uint256 amount_); // log when approved total changes
    event Draw(address indexed dst_, uint256 amount_, bool accessSuckStatus); // log upon draw
    event NewWithdrawAfter(uint256 timestamp_); // logs new withdraw expiry timestamp
    event Withdraw(uint256 amount_); // logs amount withdrawn from backup balance

    // --- UTILS ---
    /// Return dai balance held by the gate contract
    /// @return amount rad
    function daiBalance() public view returns (uint256) {
        return VatAbstract(vat).dai(address(this));
    }

    function _max(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? y : x;
    }

    /// Transfer dai balance from gate to destination address
    /// @param dst_ destination address
    /// @param amount_ dai amount to send
    /// @dev amount_ is in rad
    function transferDai(address dst_, uint256 amount_) internal {
        // check if sufficient dai balance is present
        require(amount_ <= daiBalance(), "gate/insufficient-dai-balance");

        VatAbstract(vat).move(address(this), dst_, amount_); // transfer as vat dai balance
    }

    /// Return the maximum draw amount possible from all paths
    /// Both draw limit on suck and backup balance are considered
    /// @dev Possible failure of the vat.suck call due to auth issues et cetra is not accounted for
    /// @return amount rad
    function maxDrawAmount() external view returns (uint256) {
        return _max(approvedTotal, daiBalance()); // only one source can be accessed in a single call
    }

    // --- Draw Limits ---
    /// Update draw limit
    /// @dev Restricted to authorized governance addresses
    /// @dev Approved total can be updated to both a higher or lower value
    /// @param newTotal_ Updated approved total amount
    function updateApprovedTotal(uint256 newTotal_) external auth {
        approvedTotal = newTotal_; // update approved total amount

        emit NewApprovedTotal(newTotal_);
    }

    /// Draw limit implementation
    /// Returns true upon successful vat.suck call
    /// Returns false when vat is not live or vat.suck call fails or draw limit check fails
    /// @dev Does not revert when vat.suck fails to ensure gate can try alternate draw paths
    /// @dev and determine best course of action, ex: try backup balance
    /// @param amount_ dai amount to draw from a vat.suck() call
    /// @return status
    function accessSuck(uint256 amount_) internal returns (bool) {
        // vat live status
        bool vatLive = (VatAbstract(vat).live() == 1);

        // ensure approved total to access vat.suck is greater than draw amount requested
        bool drawLimitCheck = (approvedTotal >= amount_);

        if(vatLive && drawLimitCheck) { // checks passed
            // decrease approvedTotal by draw amount
            approvedTotal = approvedTotal - amount_;

            // call suck to transfer dai from vat to this gate contract
            try VatAbstract(vat).suck(address(vow), address(this), amount_) {
                // accessSuck success- successful vat.suck execution for requested amount
                return true;
            } catch {
                // accessSuck failure-  failed vat.suck call
                return false;
            }
        } else { // checks failed
            // accessSuck failure- vat not live or insufficient draw limit(approvedTotal)
            return false;
        }
    }

    // --- Draw Functions ---
    /// Internal Draw implementation
    /// Draw can be successful even after accessSuck failure(returns false) when sufficient backup balance is present
    /// @dev Draw will fail in this design even if the combined balance from draw limit
    /// @dev and backup balance adds up to the amount requested
    /// @dev This design can only draw dai from a single source, either vat.suck() or backup dai balance, in a single draw call
    /// @param dst_ destination address to send drawn dai
    /// @param amount_ dai amount sent, rad
    function _draw(address dst_, uint256 amount_) internal {
        bool suckStatus = accessSuck(amount_); // try drawing amount from vat.suck

        // amount can still come from backup balance after accessSuck fails

        // transfer amount to the input destination address
        transferDai(dst_, amount_);

        emit Draw(dst_, amount_, suckStatus); // suckStatus logs whether suck(true) or backup balance(false) was used
    }

    /// Draw function
    /// @dev Restricted to approved integration addresses
    /// @param amount_ dai amount in rad
    function draw(uint256 amount_) external toll {
        _draw(msg.sender, amount_);
    }

    /// Draw function with destination address
    /// @dev Restricted to approved integration addresses
    /// @param dst_ destination address
    /// @param amount_ dai amount in rad
    function draw(address dst_, uint256 amount_) external toll {
        _draw(dst_, amount_);
    }

    /// Vat.suck() interface for backwards compatibility with Vat
    /// @dev Restricted to approved integration addresses
    /// @param u source address to assign vat.sin balance generated by the suck call
    /// @param v destination address to send dai drawn
    /// @param rad amount of dai drawn
    function suck(address u, address v, uint256 rad) external toll {
        u; // ignored
        // accessSuck already incorporartes the vow address as u according to the specification

        _draw(v, rad); // v (destination address)
    }

    // --- Backup Balance Withdraw Restrictions ---
    /// Internal backup balance withdrawal restrictions implementation
    /// Allows or stops authorized governance addresses from withdrawing dai from the backup balance
    /// @return status true when allowed and false when not allowed
    function withdrawalConditionSatisfied() internal view returns (bool) {
        // governance is allowed to withdraw any amount of the backup balance
        // once past withdrawAfter timestamp
        bool withdrawalAllowed = (block.timestamp >= withdrawAfter);

        return withdrawalAllowed;
    }

    /// Withdraw backup balance
    /// @dev Restricted to authorized governance addresses
    /// @param dst_ destination address
    /// @param amount_ amount of dai
    function withdrawDai(address dst_, uint256 amount_) external auth {
        require(withdrawalConditionSatisfied(), "withdraw-condition-not-satisfied");
        transferDai(dst_, amount_); // withdraw dai to governance address

        emit Withdraw(amount_);
    }

    /// Update withdrawAfter timestamp
    /// Can only set withdrawAfter to a higher timestamp
    /// @dev Restricted to authorized governance addresses
    /// @param newWithdrawAfter New timestamp to set
    function updateWithdrawAfter(uint256 newWithdrawAfter) external auth {
        require(newWithdrawAfter > withdrawAfter, "withdrawAfter/value-lower");
        withdrawAfter = newWithdrawAfter;

        emit NewWithdrawAfter(newWithdrawAfter);
    }
}
