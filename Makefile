# No default tag, so an existing release (the sites' rollback) is never
# overwritten by accident.
ifndef TAG
$(error TAG is required, e.g. make build TAG=8.4.2)
endif
PROJECT = dsh-drupal
IMAGE_NAME = singularo/$(PROJECT):$(TAG)

# Latest New Relic PHP agent: the release/ folder only holds the current one.
NEWRELIC_VERSION = $(shell curl -fsSL https://download.newrelic.com/php_agent/release/ | grep -oE 'newrelic-php5-[0-9.]+-linux\.tar\.gz' | head -1 | sed -E 's/newrelic-php5-(.*)-linux\.tar\.gz/\1/')
BUILD_ARGS = --build-arg NEWRELIC_VERSION=$(NEWRELIC_VERSION)

.PHONY: build
build: pull
	archives/update.sh
	hadolint Dockerfile
	docker build --progress plain $(BUILD_ARGS) -t $(IMAGE_NAME) .

.PHONY: rebuild
rebuild: clean pull
	archives/update.sh
	hadolint Dockerfile
	docker build --progress plain --no-cache $(BUILD_ARGS) -t $(IMAGE_NAME) .

.PHONY: tag
tag:
	docker tag $(IMAGE_NAME) $(IMAGE_NAME)

.PHONY: push
push:
	docker push $(IMAGE_NAME)

.PHONY: clean
clean:
	rm -f archives/*.tar.xz
	docker rmi -f $(IMAGE_NAME)

.PHONY: test
test:
	docker build $(BUILD_ARGS) -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run

.PHONY: pull
pull:
	docker pull $(shell grep FROM Dockerfile | cut -d' ' -f2)
