-include .env


# Update libs
update :; forge update


# Test all
test:
	make -s test-fundme
	make -s test-lottery
	make -s test-tokenico
	make -s test-defiantaave

# Test FundMe
test-fundme:
	make -s unit-test-fundme
	make -s integration-test-fundme

# Test Lottery
test-lottery:
	make -s unit-test-lottery
	make -s integration-test-lottery

# Test TokenIco
test-tokenico:
	make -s unit-test-tokenico
	make -s integration-test-tokenico

# Test Defiant
test-defiantaave:
	make -s unit-test-defiantaave
	make -s integration-test-defiantaave

# Run unit or integration tests for FundMe
unit-test-fundme :; make -s all-unit-tests c=FundMe
integration-test-fundme :; make -s all-integration-tests c=FundMe

# Run unit or integration tests for Lottery
unit-test-lottery :; make -s all-unit-tests c=Lottery
integration-test-lottery :; make -s all-integration-tests c=Lottery

# Run unit or integration tests for TokenIco
unit-test-tokenico :; make -s all-unit-tests c=TokenIco
integration-test-tokenico :; make -s all-integration-tests c=TokenIco

# Run unit or integration tests for Defiant
unit-test-defiant :; forge test --match-contract DefiantUnitTest --fork-url $(ETH_RPC_URL)
integration-test-defiant :; make -s all-integration-tests c=Defiant


# Check gas usage quickly
gas :; forge test --match-test test$(t) --force


####################
# NOT FOR ENDUSERS #
####################

all-unit-tests :; forge test --match-contract $(c)UnitTest
all-integration-tests :; forge test --match-contract $(c)IntegrationTest --fork-url $(ETH_RPC_URL)