#!/bin/bash


buildArguments(){
    echo -n "--arg storePath \"$STORE_PATH\" "
    for arg_name in $UNHOLY_ARGUMENTS; do
	varname="UNHOLY_ARG_$arg_name"
	# the trailing space is VERY important
	# the value of the environment variable must be already properly
	# quoted depending on the type of value
	echo -n "--arg $arg_name ${!varname} "
    done
}

if (! test -x $OUTPUT_DIR); then
    mkdir -p $OUTPUT_DIR
fi

# load the nix environment variables
. .bash_profile

set -eux
nix-build $(buildArguments)  $UNHOLY_EXPRESSION -o $RESULT_LINK
