IMAGE_NAME = singularo/s2i-shepherd-drupal

build:
	docker pull ubuntu:latest
	docker build -t $(IMAGE_NAME) .

clean:
	docker rmi $(IMAGE_NAME)

test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
