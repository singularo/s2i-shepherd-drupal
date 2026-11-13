
# This is an s2i builder image for drupal.

Original instructions available here - https://github.com/openshift/source-to-image

## Execute build
```bash
IMAGE_NAME=singularo/s2i-shepherd-drupal
docker build --build-arg NEWRELIC_VERSION=12.12.0.41 -t ${IMAGE_NAME} .
```
NEWRELIC_VERSION is required. The Makefile looks up the latest one itself.

## Building the main runtime image.
The builder image can also be created by using the *make* command since a *Makefile* is included.
```bash
make TAG=8.4.2
```
TAG is required. `make rebuild TAG=...` does the same from scratch (no Docker cache).

## Making the image public
Once happy with local testing the image(s), both images can be pushed to the repo with:

```bash
make TAG=8.4.2
make tag TAG=8.4.2
make push TAG=8.4.2
```

## Newrelic support.
To enable newrelic, add lines like these examples to your .env file. LICENSE is the important one, APP should
be different for each thing being monitored.
```bash
NEWRELIC_ENABLED=true
NEWRELIC_LICENSE="e33dbhas63nhgasd76t3e4hjgasd73edjhga80bNRAL"
NEWRELIC_APP="whatever-app"
```

### php-fpm
* Running the lightweight s6 init system
* Multiple processes per container
    * apache2
    * php-fpm
    * s6 syslog interface
* Helpful links used in setup:
    * https://skarnet.org/software/s6/index.html
    * https://github.com/just-containers/s6-overlay
    * https://github.com/shinsenter/php
    * https://github.com/weahead/docker-drupal
    * https://github.com/serversideup/docker-php
