.PHONY: test test-api test-reminders test-web migrate

test: test-api test-reminders test-web

test-api:
	cd services/booking-api && go test ./...

test-reminders:
	cd services/reminders && pytest

test-web:
	cd apps/web && npm run lint && npm run build

migrate:
	for f in db/migrations/*.sql; do psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$$f"; done

.PHONY: gloss
gloss: ## lint markers and refresh the committed graph
	gloss check
	gloss build -q
