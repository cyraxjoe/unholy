#!/bin/bash
#########################################################
# Support functions
#########################################################
getBuildId(){
    local outEnv=$(basename $out)
    # use the first 20 chars from the outpath hash
    echo "${outEnv:0:20}"
}

safeFileNameFromStorePath(){
    local filename=$(basename $1)
    # remove the first 23 characters of the filename,
    # instead of removing all the hash part (32 + 1 ["-"])
    # we keep some to optimistically trying to avoid
    # name colission in the files and remove the trace
    # of the original nix dependency by not having the full hash,
    # keep 10 chars from the hash plus -
    echo "${filename:23}"
}

topDirNameInTar(){
    tar -tjf $1 2>/dev/null | head -1 | cut -f1 -d"/"
}

copySrc() {
    # for now we always create the directory and it will always be copied into
    # the container. ideally this should only be copied as needed.
    mkdir $DOCKER_CONTEXT/source

    if [ -n $mainBuildSource ]; then
        echo "Found required source ${mainBuildSource}. Copying to ${DOCKER_CONTEXT}/source"
        cp -r $mainBuildSource/* $DOCKER_CONTEXT/source -v
    fi
}

configureBuildArgument(){
    local arg_name=$1
    local arg_value="$2"
    local unholyIntegerRegex="^${unholyIntegerPrefix}:[0-9]+$"
    declare -a commands
    echo "Configuring build argument '$arg_name'"
    if [[ -e $arg_value ]]; then
        # if it exists in the filesystem we assume is a file
         local safe_name=$(safeFileNameFromStorePath $arg_value)
        # move from the origin into the docker context
        cp -r $arg_value $DOCKER_CONTEXT/
        # rename
        mv $DOCKER_CONTEXT/$(basename $arg_value) "$DOCKER_CONTEXT/$safe_name"
        local arg_path_dest="$ARGS_DIR/$safe_name"
        # forge the dockerfile commands
        commands=("${commands[@]}" "COPY \"$safe_name\" \"$arg_path_dest\"")
        commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name \"$arg_path_dest\"")
    elif [[ $arg_value =~ $unholyIntegerRegex ]]; then # is an integer
        # extract the actual integer that was passed
        local integer_value="${arg_value##*:}"
        commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name $integer_value")
    else
        case "$arg_value" in
            "$unholyTrueValue")
                commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name true")
            ;;
            "$unholyFalseValue")
                commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name false")
            ;;
            "$unholyNullValue")
                commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name null")
            ;;
            "$unholyEmptyStringValue")
                commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name '\"\"'")
            ;;
            *) # assume that anything else is a string
               # (not a file, integer, null, false, true, empty string)
                commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name '\"$arg_value\"'")
            ;;
        esac
    fi
    echo "$arg_name" >> $CUSTOM_ARGS_NAMES_FILE
    printf '%s\n' "${commands[@]}"  >> $CUSTOM_ARGS_FILE
}


setupCustomArguments(){
    # we are consuming the argument two at a time,
    # on a SUB-SHELL therefore... we are not sharing
    # the same variable space (in terms of writing into
    # the one at the top-level), all the argument
    # processing is done indirectly by appending to
    # CUSTOM_ARGS_NAMES_FILE and CUSTOM_ARGS_FILE
    echo $buildArgs | sed 's/ /\n/g' | {
        local arg_name
        local arg_value
        while read arg_name
        do
            read arg_value
            configureBuildArgument $arg_name "$arg_value"
        done
    }
    local names=$(cat $CUSTOM_ARGS_NAMES_FILE | tr "\n" " " | head -c -1)
    echo "ENV UNHOLY_ARGUMENTS \"$names\"" >>  $CUSTOM_ARGS_FILE
}


setupNixBinaryInstaller(){
    if [[ $nixInstallerComp == ".tar.bz2" ]]; then
        cp $nixInstaller nix-installer.tar.bz2
        # output stderr in to /dev/null because apparently tar can handle
        # list command with the pipe filtering of head+cut, it reports a "tar: write error"
        local nix_dir_name=$(topDirNameInTar nix-installer.tar.bz2)
        # extract and delete
        tar -xjf nix-installer.tar.bz2 && rm nix-installer.tar.bz2
        mv $nix_dir_name $DOCKER_CONTEXT/nix-binary-installer
    elif [[ -z $nixInstallerComp ]]; then # assume is a directory
        cp -R $nixInstaller $DOCKER_CONTEXT/nix-binary-installer
    else
        echo "Unable to determine how to obtain the nix binary installer" >&2
        exit 1
    fi
}


makeDockerBuild(){
    mkdir $DOCKER_CONTEXT
    cp $dockerFile $DOCKER_CONTEXT/Dockerfile
    # this can be a single file or a directory with default.nix
    cp -r $unholyExpression $DOCKER_CONTEXT/unholy-expression
    cp $entryPoint $DOCKER_CONTEXT/entrypoint.sh
    cp $buildScript $DOCKER_CONTEXT/build.sh
    setupNixBinaryInstaller
    setupCustomArguments
    # copy the given source into the container to be used in the build
    copySrc
    chmod +w $DOCKER_CONTEXT/Dockerfile
    # get the dockerfile fragment configuration of the
    # custom arguments, and remove the last line break
    CUSTOM_ARGS="$(cat $CUSTOM_ARGS_FILE | head -c -1)"
    substituteInPlace $DOCKER_CONTEXT/Dockerfile \
                      --subst-var out \
                      --subst-var outputs \
                      --subst-var targetSystemBuildDependencies \
                      --subst-var CUSTOM_ARGS \
                      --subst-var ARGS_DIR
    #echo "Final dockerfile"
    #echo "============================"
    #cat $DOCKER_CONTEXT/Dockerfile
    #echo "============================"
    pushd $DOCKER_CONTEXT
    local buildFlags="--tag $DOCKER_IMG_NAME"
    if [[ -n $alwaysRemoveBuildContainers ]]; then
        # remove all the intermediate containers, even if the build fails
        buildFlags+=" --force-rm"
    fi
    if [[ -n $noBuildCache ]]; then
        buildFlags+=" --no-cache"
    fi
    echo "executing docker build with the flags '$buildFlags'"
    dockerWrapper build $buildFlags .
    # we don't care about the dir, output to null
    popd > /dev/null
}

extractOutput(){
    local dir="$1"
    local output="$2"
    local intermediateTar="build-${output}.tar"
    mkdir $dir
    # we could avoid the creation of the tar itself.. but it was usefull
    # to debug, consider piping the output directly to tar if we care
    # about the storage
    dockerWrapper run --rm "$DOCKER_IMG_NAME" tar $output  > $intermediateTar
    tar --directory $dir --extract -f $intermediateTar
}

importProducts(){
    local dir="$1"
    local output="$2"
    local hydra_products_in_docker log
    # we have to make writable some of the directories
    # that are coming from the tar, because they were
    # extracted from a nix store (with read-only on
    # pretty much everything)
    chmod +w $dir
    if [[ -e $dir/nix-support ]]; then
        # the nix-support directory might not exists if we are not
        # logging this execution
        ensureNixSupportDir "${!output}"
        chmod +w $dir/nix-support/
        mv $dir/nix-support "${!output}/nix-support/in-docker"
        hydra_products_in_docker="${!output}/nix-support/in-docker/hydra-build-products"
        if [[ -e $hydra_products_in_docker ]]; then
            # copy over the products from the docker build
            # that were built in our 'output' path
            grep "${!output}" $hydra_products_in_docker >> $HYDRA_BUILD_PRODUCTS_FILE
        fi
    fi
    # if we have an internal log, copy it
    if [[ -e $dir/var/log ]]; then
        mkdir -p "${!output}/var/log/in-docker"
        chmod +w $dir/var $dir/var/log
        mv $dir/var/log/* "${!output}/var/log/in-docker/"
        rm -rf $dir/var/log/
        # add the docker logs as hydra proucts
        for log in "${!output}/var/log/in-docker/*"; do
            addHydraBuildProduct file log "$log"
        done
    fi
    cp -a $dir/* "${!output}/"
}

extractBuildFromDockerImage(){
    echo "Extracting build"
    local docker_product_dir output
    for output in $outputs; do
        docker_product_dir="docker-product-${output}"
        extractOutput "$docker_product_dir" "$output"
        importProducts "$docker_product_dir" "$output"
    done

    if [[ -n "$keepBuildImage" ]]; then
        echo "******************************************************"
        echo "Keeping build image: '$DOCKER_IMG_NAME'."
        echo "******************************************************"
    else
        if [[ -n "$pruneUntaggedParents" ]]; then
            dockerWrapper image rm "$DOCKER_IMG_NAME"
        else
            echo "******************************************************"
            echo "Removing build image, but keeping untagged parents."
            echo "Make sure you prune the images later if you don't care about the cache."
            echo "To prune the images execute: 'docker image prune'"
            echo "******************************************************"
            dockerWrapper image rm --no-prune "$DOCKER_IMG_NAME"
        fi
    fi
}

dockerWrapper(){
    docker $*
}
#########################################################
# End of support functions
#########################################################
set -e
# use the base directory name in the nix store as the
# base of the build image name, alternatively we could
# use the plain hash to have a single name (repo) with
# a changing tag depending on the nix store hash
BUILD_ID=$(getBuildId)
DOCKER_IMG_NAME="$BUILD_ID-build-env"
DOCKER_CONTEXT="docker-context"
ARGS_DIR="\$HOME/_arguments"
CUSTOM_ARGS_NAMES_FILE="_arg_names"
CUSTOM_ARGS_FILE="_args"



# we don't need the conditional &&, we're already at the mercy of errexit,
# if we were to use "&&", it would have the effect that it would ignore the errexit
# behavior inside the function (not failing on the first error)
makeDockerBuild
extractBuildFromDockerImage
