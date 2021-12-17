APP_NAME := $(shell git remote -v | awk '/origin/ && /fetch/ { sub(/\.git/, ""); n=split($$2, origin, "/"); print origin[n]}')
BUILD_DATESTAMP := $(shell date -u '+%Y%m%dT%H%M%SZ')
GIT_BRANCH := $(shell git branch --show-current)
GIT_SHA1 := $(shell git log --pretty=format:'%h' -n 1)
GIT_URL := $(shell git remote get-url origin | sed 's/https:\/\/.*\@github.com/https:\/\/github.com/')

BUILD_DIR ?= deployment/kubernetes
BUILD_ENV ?= $(TMP_DIR)/build-env
ifndef BUILD_TAG
    BUILD_TAG := localbuild://${USER}@$(shell uname -n | sed "s/'//g")
endif
ORG_NAME ?= answerbook
RELEASE_BRANCHES ?= main
RELEASE_DIR ?= release
TMP_DIR ?= tmp

DOCKER_RUN ?= docker run --rm -i
DOCKER_RUN_BUILD_ENV ?= $(DOCKER_RUN) --env-file=$(BUILD_ENV)

ENVSUBST_COMMAND ?= $(DOCKER_RUN_BUILD_ENV) -v $(PWD):/data:Z bhgedigital/envsubst envsubst "$$(printf '$${%s} ' $$(cut -f1 -d'=' ${BUILD_ENV}))"
GH_COMMAND ?= $(DOCKER_RUN) -e GITHUB_TOKEN -v $(PWD):/data:Z -w /data us.gcr.io/logdna-k8s/gh:latest gh
KUBEVAL_COMMAND ?= $(DOCKER_RUN) -v $(PWD):/data:Z garethr/kubeval --ignore-missing-schemas
YAMLLINT_COMMAND ?= $(DOCKER_RUN) -v $(PWD):/data:Z cytopia/yamllint:latest

BUILD_ARTIFACTS := $(wildcard $(BUILD_DIR)/*.yaml.envsubst)
RELEASE_ARTIFACTS := $(patsubst $(BUILD_DIR)/%.envsubst, $(RELEASE_DIR)/%, $(BUILD_ARTIFACTS))
RELEASE_VERSION := $(BUILD_DATESTAMP)

include versions.mk

export

.PHONY:build clean debug-% lint publish test

DRAFT =
ifneq ($(GIT_BRANCH), $(filter $(RELEASE_BRANCHES), $(GIT_BRANCH)))
    DRAFT = --draft
endif

$(RELEASE_DIR) $(TMP_DIR):
	@mkdir -p $(@)

$(RELEASE_DIR)/%: $(BUILD_DIR)/%.envsubst $(BUILD_ENV) | $(RELEASE_DIR)
	$(ENVSUBST_COMMAND) < $(<) > $(@)

$(BUILD_ENV): $(TMP_DIR)
	@env | awk '!/TOKEN/ && /^(GIT|BUILD|WAVE)/ { print }' | sort > $(@)

build: $(RELEASE_ARTIFACTS)

clean:
	rm -rf $(RELEASE_DIR) $(TMP_DIR)

debug-%:              ## Debug a variable by calling `make debug-VARIABLE`
	@echo $(*) = $($(*))

lint: $(RELEASE_ARTIFACTS)
	$(YAMLLINT_COMMAND) /data/$(RELEASE_DIR)

publish: $(RELEASE_ARTIFACTS)
	$(GH_COMMAND) release create --repo $(ORG_NAME)/$(APP_NAME) $(DRAFT) $(RELEASE_VERSION) $(RELEASE_ARTIFACTS)

test: $(RELEASE_ARTIFACTS)
	$(KUBEVAL_COMMAND) -d /data/$(RELEASE_DIR)
