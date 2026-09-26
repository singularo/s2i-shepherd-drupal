# Static tag otherwise how to test before commit?
TAG = 8.4.0
PROJECT = dsh-drupal
IMAGE_NAME = singularo/$(PROJECT):$(TAG)

.PHONY: build
build: pull
	archives/update.sh
	hadolint Dockerfile
	docker build --progress plain -t $(IMAGE_NAME) .

.PHONY: rebuild
rebuild: clean
	archives/update.sh
	docker build --progress plain --no-cache -t $(IMAGE_NAME) .

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
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run

.PHONY: pull
pull:
	docker pull $(shell grep FROM Dockerfile | cut -d' ' -f2)
