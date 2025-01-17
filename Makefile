SHELL := /bin/bash

.DEFAULT_GOAL := help

.PHONY: build
build: ## Build docker image for develop environment
	docker build -t zenn:20 .

.PHONY: up
up: ## Start the container
	docker compose up -d

.PHONY: down
down: ## Delete the container
	docker compose down

.PHONY: node
node: ## Enter node container
	docker compose exec node bash

.PHONY: yarn-install
yarn-install: ## Install packages
	docker compose run --rm node yarn

.PHONY: help
help: ## Display a list of targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
