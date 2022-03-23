all             :; forge build
clean           :; forge clean
                   # Usage example: make test match=TestNameHere
test            :; ./test-dss-gate.sh
test-forge      :; ./test-dss-gate-forge.sh
deploy          :; make && forge create Gate1
