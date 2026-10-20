.PHONY: up schemas test test-intake test-fraud test-assessment test-notifier test-contract

up:
	docker compose up -d
schemas:
	SCHEMA_REGISTRY_URL=http://localhost:8081 schemas/register.sh

test: test-contract test-intake test-fraud test-assessment test-notifier
test-contract:
	cd contracts && python -m pytest -q
test-intake:
	cd services/claim-intake && gradle test
test-fraud:
	cd services/fraud-screening && gradle test
test-assessment:
	cd services/assessment && python -m pytest -q
test-notifier:
	cd services/payout-notifier && go test ./...

.PHONY: gloss
gloss: ## lint markers and refresh the committed graph
	gloss check
	gloss build -q
