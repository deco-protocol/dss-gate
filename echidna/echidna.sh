#!/usr/bin/env bash

# Script to run echidna fuzz tests of Dss-Gate
# Copyright (C) 2022 Deco Inc.,

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https:#www.gnu.org/licenses/>.

set -e

echo "Running ECHIDNA tests for dss-gate";

SOLC=~/.nix-profile/bin/solc-0.8.1

# Echidna Fuzz Test Contract Name
readonly ECHIDNA_CLAIMFEE_CONTRACT_NAME=DssGateEchidnaTest

# Invoke Echidna ACCeSS INVARIANT tests for claim fee maker contract
echidna-test echidna/"$ECHIDNA_CLAIMFEE_CONTRACT_NAME".sol --contract "$ECHIDNA_CLAIMFEE_CONTRACT_NAME" --config echidna.config.yml