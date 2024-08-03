TAG = $(shell git rev-parse --abbrev-ref HEAD)
PROJECT = s2i-shepherd-drupal
IMAGE_NAME = singularo/$(PROJECT):$(TAG)

.PHONY: build
build:
	archives/update.sh
	docker build -t $(IMAGE_NAME) .

.PHONY: tag
tag:
	docker tag $(IMAGE_NAME) $(IMAGE_NAME)

.PHONY: push
push:
	docker push $(IMAGE_NAME)

.PHONY: clean
clean:
	rm -f archives/*.tar.xz
	docker rmi $(IMAGE_NAME)

.PHONY: test
test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
