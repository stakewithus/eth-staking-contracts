include .env

.PHONY: test

test-unit:; FOUNDRY_PROFILE=unit forge test $(args)
test-integration:; FOUNDRY_PROFILE=integration forge test $(args)