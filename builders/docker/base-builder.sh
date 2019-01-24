#!/bin/bash

# use the base directory name in the nix store as the
# base of the build image name, alternatively we could
# use the plain hash to have a single name (repo) with
# a changing tag depending on the nix store hash
DOCKER_IMG_NAME="${out##*/}-build-env"
DOCKER_CONTEXT="docker-context"
DOCKER_PRODUCT="docker-product"

dockerWrapper(){
    if [[ $useSudo ]]; then
        if [[ $sudoUser ]]; then
            sudo docker -u "$sudoUser" $*
        else
            sudo docker $*
        fi
    else
        docker $*
    fi
}


makeDockerBuild(){
    mkdir $DOCKER_CONTEXT
    cp -R $unholySrc $DOCKER_CONTEXT/unholy
    cp $dockerFile $DOCKER_CONTEXT/Dockerfile
    # this can be a single file or a directory with default.nix
    cp -r $unholyExpression $DOCKER_CONTEXT/unholy-expression
    cp $entryPoint $DOCKER_CONTEXT/entrypoint.sh
    cp $buildScript $DOCKER_CONTEXT/build.sh
    substituteInPlace $DOCKER_CONTEXT/Dockerfile \
                      --subst-var targetSystemBuildDependencies
    pushd $DOCKER_CONTEXT
    dockerWrapper build -t $DOCKER_IMG_NAME --build-arg STORE_PATH=$out .
    popd
}

extractBuildFromDockerImage(){
    mkdir $DOCKER_PRODUCT
    dockerWrapper run --rm "$DOCKER_IMG_NAME" tar  > build.tar
    tar --directory $DOCKER_PRODUCT --extract -f build.tar
    # we have to make writiable some of the directories
    # that are comming from the tar, because they were
    # extracted from a nix store (with read-only on
    # pretty much everything)
    chmod +w $DOCKER_PRODUCT
    if [[ -e $DOCKER_PRODUCT/nix-support ]]; then
        chmod +w $DOCKER_PRODUCT/nix-support/
        mv $DOCKER_PRODUCT/nix-support $out/nix-support/in-docker
        local hydra_products_in_docker=$out/nix-support/in-docker/hydra-build-products
        if [[ -e $hydra_products_in_docker ]]; then
            # copy over the products from the docker build
            # that were built in our 'out' path
            grep "$out" $hydra_products_in_docker >> $HYDRA_BUILD_PRODUCTS_FILE
        fi
    fi
    # if we have an internal log, copy it
    if [[ -e $DOCKER_PRODUCT/var/log ]]; then
        mkdir -p $out/var/log/in-docker
        chmod +w $DOCKER_PRODUCT/var $DOCKER_PRODUCT/var/log
        mv $DOCKER_PRODUCT/var/log/* $out/var/log/in-docker/
        rm -rf $DOCKER_PRODUCT/var/log/
    fi
    cp -a $DOCKER_PRODUCT/* $out/

    if [[ -n "$keepBuildImage" ]]; then
        echo "Keeping build image: '$DOCKER_IMG_NAME'"
    else
        dockerWrapper image rm "$DOCKER_IMG_NAME"
    fi
}


makeDockerBuild && extractBuildFromDockerImage
