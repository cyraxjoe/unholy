#!/bin/bash

if (! test -x $OUTPUT_DIR); then
    mkdir -p $OUTPUT_DIR
fi

# load the nix environment variables
. .bash_profile

nix-build --arg unholy $UNHOLY_SRC \
          --arg storePath \"$STORE_PATH\" $UNHOLY_EXPRESSION \
          -o $RESULT_LINK
