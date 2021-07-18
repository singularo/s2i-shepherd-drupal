IMAGE_NAME = singularo/s2i-shepherd-drupal
PHP_VERSION = 7.4

.PHONY: build
build:
	hadolint Dockerfile
	docker build -t $(IMAGE_NAME):$(PHP_VERSION) --build-arg PHP_VERSION=$(PHP_VERSION) .

.PHONY: test
test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
