.PHONY: test test-api test-kds migrate

test: test-api test-kds

test-api:
	cd api && pytest

test-kds:
	cd kds && npm run lint && npm test

migrate:
	for f in db/migrations/*.sql; do psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$$f"; done

.PHONY: gloss
gloss: ## lint markers and refresh the committed graph
	gloss check
	gloss build -q
