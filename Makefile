IMAGE_NAME = singularo/s2i-shepherd-drupal:8.1

.PHONY: build
build:
	docker pull ubuntu:22.04
	hadolint Dockerfile
	docker build -t $(IMAGE_NAME) .

.PHONY: clean
clean:
	docker rmi $(IMAGE_NAME)

.PHONY: test
test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
