all             :; dapp build
clean           :; dapp clean
                    # Usage example: make test match=Withdraw
test            :; make && ./test-dss-gate.sh $(match)
deploy          :; make && dapp create Gate1 $(vow)
