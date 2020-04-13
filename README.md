
# This is an s2i builder image for drupal.

Original instructions available here - https://github.com/openshift/source-to-image

Execute build
```bash
IMAGE_NAME=singularo/s2i-shepherd-drupal
docker build -t ${IMAGE_NAME} .
```

The builder image can also be created by using the *make* command since a *Makefile* is included.

Now when you deploy from shepherd, it will use the updated singularo/s2i-shepherd-drupal image with your changes.
