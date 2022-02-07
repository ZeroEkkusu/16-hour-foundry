# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

unit-test-fundme :; forge test --match-contract "FundMeUnitTest"
integration-test-fundme :; forge test --match-contract "FundMeIntegrationTest" --fork-url $$ETH_RPC_URL
test-fundme :; make unit-test-fundme && make integration-test-fundme

unit-test-lottery :; forge test --match-contract "LotteryUnitTest"
integration-test-lottery :; forge test --match-contract "LotteryIntegrationTest" --fork-url $$ETH_RPC_URL
test-lottery :; make unit-test-lottery && make integration-test-lottery

test :; make test-fundme && make test-lottery