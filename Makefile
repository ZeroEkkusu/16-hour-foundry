-include .env

# Test all
test:
	make -s test-fundme
	make -s test-lottery
	make -s test-tokenwithico

# Test FundMe
test-fundme:
	make -s unit-test-fundme
	make -s integration-test-fundme

# Test Lottery
test-lottery:
	make -s unit-test-lottery
	make -s integration-test-lottery

# Test ModernToken
test-tokenwithico:
	make -s unit-test-tokenwithico
	make -s integration-test-tokenwithico

# Run unit or integration tests for FundMe
unit-test-fundme :; make -s all-unit-tests c=FundMe
integration-test-fundme :; make -s all-integration-tests c=FundMe

# Run unit or integration tests for Lottery
unit-test-lottery :; make -s all-unit-tests c=Lottery
integration-test-lottery :; make -s all-integration-tests c=Lottery

# Run unit or integration tests for ModernToken
unit-test-tokenwithico :; make -s all-unit-tests c=ModernToken
integration-test-tokenwithico :; make -s all-integration-tests c=ModernToken

# Check gas usage quickly
gas :; forge test --match-test $(t) --force

####################
# NOT FOR ENDUSERS #
####################

all-unit-tests :; forge test --match-contract $(c)UnitTest
all-integration-tests :; forge test --match-contract $(c)IntegrationTest --fork-url $(ETH_RPC_URL)