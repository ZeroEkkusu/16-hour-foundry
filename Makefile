
# Export environment variables
-include .env


# Test all contracts
test:
	make -s test-FundMe
	make -s test-Lottery
	make -s test-TokenIco
	make -s test-Defiant
	make -s test-Soulbound

# Test FundMe
test-FundMe:
	make -s unit-test-FundMe
	make -s integration-test-FundMe

# Test Lottery
test-Lottery:
	make -s unit-test-Lottery
	make -s integration-test-Lottery

# Test TokenIco
test-TokenIco:
	make -s unit-test-TokenIco
	make -s integration-test-TokenIco

# Test Defiant
test-Defiant:
	make -s unit-test-Defiant
	make -s integration-test-Defiant

#Test Soulbound
test-Soulbound:
	make -s unit-test-Soulbound

# Run unit or integration tests for FundMe
unit-test-FundMe :; make -s all-unit-tests c=FundMe
integration-test-FundMe :; make -s all-integration-tests c=FundMe

# Run unit or integration tests for Lottery
unit-test-Lottery :; make -s all-unit-tests c=Lottery
integration-test-Lottery :; make -s all-integration-tests c=Lottery

# Run unit or integration tests for TokenIco
unit-test-TokenIco :; make -s all-unit-tests c=TokenIco
integration-test-TokenIco :; make -s all-integration-tests c=TokenIco

# Run unit or integration tests for Defiant
unit-test-Defiant :; forge test --match-contract DefiantUnitTest --fork-url $(ETH_RPC_URL)
integration-test-Defiant :; make -s all-integration-tests c=Defiant

#Run unit tests for Soulbound
unit-test-Soulbound :; forge test --match-contract SoulboundTest --fork-url $(ETH_RPC_URL)


####################
# NOT FOR ENDUSERS #
####################

all-unit-tests :; forge test --match-contract $(c)UnitTest
all-integration-tests :; forge test --match-contract $(c)IntegrationTest --fork-url $(ETH_RPC_URL)