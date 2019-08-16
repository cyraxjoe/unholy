#!/bin/bash
# source the bash profile, this script is expected to be
# ran from the home of the unholy build user
. .bash_profile

params=( $@ )

# TODO: remove nix-store commands and find the correct dir for the output
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
        output="${params[1]}"
        if [[ -n "$output" ]] && [[ $output != "out" ]]; then
            cd "${RESULT_LINK}-${output}"
        else
            cd $RESULT_LINK
        fi
        cd /home/unholy-user/exports/
        tar  --create ./*
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
