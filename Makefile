unit-test-fundme :; forge test --match-contract "FundMeUnitTest"
integration-test-fundme :; . ./.env && forge test --match-contract "FundMeIntegrationTest" --fork-url $$ETH_RPC_URL

unit-test-lottery :; forge test --match-contract "LotteryUnitTest"
integration-test-lottery :; . ./.env && forge test --match-contract "LotteryIntegrationTest" --fork-url $$ETH_RPC_URL