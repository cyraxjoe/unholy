set -eu
source $setupEnvPath
source $stdenvUtilsPath
NIX_SUPPORT_DIR="$out/nix-support"
NIX_FAILED_BUILD_FILE="$NIX_SUPPORT_DIR/failed"
HYDRA_BUILD_PRODUCTS_FILE="$NIX_SUPPORT_DIR/hydra-build-products"
LOG_DIR="$out/var/log"
DETAILED_BUILD_LOG="$LOG_DIR/build.log"

ensureNixSupportDir() {
    if [[ ! -d $NIX_SUPPORT_DIR ]]; then
        mkdir $NIX_SUPPORT_DIR
    fi
}

addHydraBuildProduct() {
    ensureNixSupportDir
    local type=$1
    local subtype=$2
    local path=$3
    echo "$type $subtype $path" >> $HYDRA_BUILD_PRODUCTS_FILE
}

addPropagatedDependency() {
    ensureNixSupportDir
    local base_path=$1
    local propagated_inputs=$NIX_SUPPORT_DIR/propagated-inputs
    echo $base_path >> $propagated_inputs
}

markBuildAsFailed() {
    ensureNixSupportDir
    touch $NIX_FAILED_BUILD_FILE
}

# this will create the base directory structure and build log
mkdir -p $LOG_DIR && addHydraBuildProduct file log "$DETAILED_BUILD_LOG"
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>&>(ts "[%Y-%m-%d-%H:%M:%S]" |
          sed -u 's;/nix/store/[a-zA-Z0-9]\{32,\};\<store-redacted\>;g' |
          tee $DETAILED_BUILD_LOG) 2>&1
set -x
source $scriptPath
