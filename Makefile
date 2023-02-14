TAG = php-fpm
PROJECT = s2i-shepherd-drupal
IMAGE_NAME = singularo/$(PROJECT):$(TAG)

.PHONY: build
build:
	hadolint Dockerfile
	docker build -t $(IMAGE_NAME) .

.PHONY: tag
tag:
	docker tag $(IMAGE_NAME) $(IMAGE_NAME)

.PHONY: push
push:
	docker push $(IMAGE_NAME)

.PHONY: clean
clean:
	docker rmi $(IMAGE_NAME)

.PHONY: test
test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
