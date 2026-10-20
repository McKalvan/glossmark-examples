# Convenience targets; Jenkins calls ant directly.
.PHONY: build test image db features

build:
	ant clean war

test:
	ant test

image: build
	docker build -t circ-web:$$(git rev-parse --short HEAD) .

db:
	db/apply.sh circ_dev

features:
	ant test && cucumber features/

.PHONY: gloss
gloss: ## lint markers and refresh the committed graph
	gloss check
	gloss build -q
