#!/usr/bin/env bash
set -e

echo "Running ECHIDNA tests for dss-gate";

SOLC=~/.nix-profile/bin/solc-0.8.1

# Echidna Fuzz Test Contract Name
readonly ECHIDNA_CLAIMFEE_CONTRACT_NAME=DssGateEchidnaTest

# Invoke Echidna ACCeSS INVARIANT tests for claim fee maker contract
echidna-test echidna/"$ECHIDNA_CLAIMFEE_CONTRACT_NAME".sol --contract "$ECHIDNA_CLAIMFEE_CONTRACT_NAME" --config echidna.config.yml