# Build
all             :; dapp build

# Clean
clean           :; dapp clean

# Deployment
deploy          :; make && dapp create Gate1 $(vow)

# Testing

## Unit Tests
test            :; make && ./test-dss-gate.sh $(match)

## Fuzz/Invariant tests - Echidna
echidna-dss-gate :; ./echidna/echidna.sh