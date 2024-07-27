SHELL := /bin/bash

.DEFAULT_GOAL := help

UID := $(shell id -u)
USERNAME := $(shell id -u -n)
GID := $(shell id -g)
GROUPNAME := $(shell id -g -n)

.PHONY: build
build: ## Build docker image for develop environment
	docker build -t zenn:20 .

define deleteImage
	@id=$$(docker images -f "reference=$(1)" -q); [ -n "$$id" ] && { docker rmi $$id; :; } || echo "image not found: $(1)"
endef

.PHONY: rebuild
rebuild: ## Delete images and build docker image
	@$(call deleteImage,"zenn")
	@make -s build

.PHONY: up
up: ## Start the container
	docker compose up -d

.PHONY: down
down: ## Delete the container
	docker compose down

.PHONY: node
node: ## Enter node container
	docker compose exec node bash

.PHONY: help
help: ## Display a list of targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
