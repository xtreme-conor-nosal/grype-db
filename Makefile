TEMPDIR = ./.tmp
RESULTSDIR = $(TEMPDIR)/results
COVER_REPORT = $(RESULTSDIR)/cover.report
COVER_TOTAL = $(RESULTSDIR)/cover.total
LICENSES_REPORT = $(RESULTSDIR)/licenses.json
LINTCMD = $(TEMPDIR)/golangci-lint run --tests=false --config .golangci.yaml
BOLD := $(shell tput -T linux bold)
PURPLE := $(shell tput -T linux setaf 5)
GREEN := $(shell tput -T linux setaf 2)
CYAN := $(shell tput -T linux setaf 6)
RED := $(shell tput -T linux setaf 1)
RESET := $(shell tput -T linux sgr0)
TITLE := $(BOLD)$(PURPLE)
SUCCESS := $(BOLD)$(GREEN)
# the quality gate lower threshold for unit test total % coverage (by function statements)
COVERAGE_THRESHOLD := 45

ifndef TEMPDIR
    $(error TEMPDIR is not set)
endif

define title
    @printf '$(TITLE)$(1)$(RESET)\n'
endef

.PHONY: all bootstrap lint lint-fix unit coverage integration check-pipeline clear-cache help test

all: lint check-licenses test ## Run all checks (linting, unit tests, and dependency license checks)
	@printf '$(SUCCESS)All checks pass!$(RESET)\n'

# TODO: add me back in when integration tests are implemented
test: unit #integration ## Run all tests (currently only unit)

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(BOLD)$(CYAN)%-25s$(RESET)%s\n", $$1, $$2}'

ci-bootstrap: bootstrap
	sudo apt install -y bc

bootstrap: ## Download and install all project dependencies (+ prep tooling in the ./tmp dir)
	$(call title,Downloading dependencies)
	# prep temp dirs
	mkdir -p $(TEMPDIR)
	mkdir -p $(RESULTSDIR)
	# install project dependencies
	go get ./...
	# install golangci-lint
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b .tmp/ v1.26.0
	# install bouncer
	curl -sSfL https://raw.githubusercontent.com/wagoodman/go-bouncer/master/bouncer.sh | sh -s -- -b .tmp/ v0.2.0

lint: ## Run gofmt + golangci lint checks
	$(call title,Running linters)
	@printf "files with gofmt issues: [$(shell gofmt -l -s .)]\n"
	@test -z "$(shell gofmt -l -s .)"
	$(LINTCMD)

lint-fix: ## Auto-format all source code + run golangci lint fixers
	$(call title,Running lint fixers)
	gofmt -w -s .
	$(LINTCMD) --fix

unit: ## Run unit tests (with coverage)
	$(call title,Running unit tests)
	go test -coverprofile $(COVER_REPORT) ./...
	@go tool cover -func $(COVER_REPORT) | grep total |  awk '{print substr($$3, 1, length($$3)-1)}' > $(COVER_TOTAL)
	@echo "Coverage: $$(cat $(COVER_TOTAL))"
	@if [ $$(echo "$$(cat $(COVER_TOTAL)) >= $(COVERAGE_THRESHOLD)" | bc -l) -ne 1 ]; then echo "$(RED)$(BOLD)Failed coverage quality gate (> $(COVERAGE_THRESHOLD)%)$(RESET)" && false; fi

check-pipeline: ## Run local CircleCI pipeline locally (sanity check)
	$(call title,Check pipeline)
	# note: this is meant for local development & testing of the pipeline, NOT to be run in CI
	mkdir -p $(TEMPDIR)
	circleci config process .circleci/config.yml > .tmp/circleci.yml
	circleci local execute -c .tmp/circleci.yml --job "Static Analysis"
	circleci local execute -c .tmp/circleci.yml --job "Unit Tests (go-latest)"
	@printf '$(SUCCESS)Pipeline checks pass!$(RESET)\n'

check-licenses:
	$(TEMPDIR)/bouncer list -o json | tee $(LICENSES_REPORT)
	$(TEMPDIR)/bouncer check