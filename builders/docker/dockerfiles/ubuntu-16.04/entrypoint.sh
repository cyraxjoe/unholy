#!/bin/bash

# this script is run after the Dockerfile is created and build.sh has finished
# running. docker `ENTRYPOINT`s are designed for stable commands that should be
# run as part of setting up the container. in this case the main purpose of
# the container is to generate a tar file of whatever was built, so the
# DOCKERFILE runs this script using the `ENTRYPOINT` instruction.
set -e;
set -u;

# creates a tar of whatever was built in the container and placed in the
# result folder
if [[ -n "$RESULT_LINK" ]]; then
    cd $RESULT_LINK
    tar --create ./*
else
    echo "ERROR: `ENV RESULT_LINK` must be set in the Dockerfile."
fi
