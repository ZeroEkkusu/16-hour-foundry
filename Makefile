# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

test:
	make test-fundme
	make test-lottery

test-fundme:
	make unit-test-fundme
	make integration-test-fundme

test-lottery:
	make unit-test-lottery
	make integration-test-lottery

unit-test-fundme :; forge test --match-contract FundMeUnitTest
integration-test-fundme :; forge test --match-contract FundMeIntegrationTest --fork-url $(ETH_RPC_URL)

unit-test-lottery :; forge test --match-contract LotteryUnitTest
integration-test-lottery :; forge test --match-contract LotteryIntegrationTest --fork-url $(ETH_RPC_URL)