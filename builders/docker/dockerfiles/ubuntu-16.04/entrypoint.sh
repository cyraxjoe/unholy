#!/bin/bash
# source the bash profile, this script is expected to be
# ran from the home of the unholy build user
. .bash_profile

params=( $@ )

case "${params[0]}" in
    export)
        nix-store --export "$(nix-store -qR $RESULT_LINK)"
    ;;
    dump)
        nix-store --dump "$(nix-store -qR $RESULT_LINK)"
    ;;
    tar)
        ## currently this is the only command on which we are relying on
        ## the build process, the others are niceties and some were used for
        ## experiments
        (cd $RESULT_LINK; tar  --create .)
    ;;
    path)
        readlink -e $RESULT_LINK
    ;;
    "")
        /bin/bash -l -i
        ;;
    *)
        echo "Invalid command"
        exit 1
        ;;
esac
