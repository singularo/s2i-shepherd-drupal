
# This is an s2i builder image for drupal.

Original instructions available here - https://github.com/openshift/source-to-image

## Execute build
```bash
IMAGE_NAME=singularo/s2i-shepherd-drupal
docker build -t ${IMAGE_NAME} .
```

## Building the main runtime image.
The builder image can also be created by using the *make* command since a *Makefile* is included.
```bash
make
```

## Making the image public
Once happy with local testing the image(s), both images can be pushed to the repo with:

*Note:* the IMAGE_TAG in the build-image.sh refers to the docker tag based on the branch name in the Dockerfile's.


```bash
make
make tag
make push
```

## Newrelic support.
To enable newrelic, add lines like these examples to your .env file. LICENSE is the important one, APP should
be different for each thing being monitored.
```bash
NEWRELIC_ENABLED=true
NEWRELIC_LICENSE="1b08384231238762323223233fc0ca1fe0df80bNRAL"
NEWRELIC_APP="aa-simon-local"
```

## Container style change

### Original - Apache2
* Original style based on work on the Shepherd project:
    * https://github.com/universityofadelaide/s2i-shepherd-drupal
    * https://github.com/universityofadelaide/shepherd
* Single process per container
* apache2 is the main process
* php loaded as a module.

### Now - php-fpm
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
