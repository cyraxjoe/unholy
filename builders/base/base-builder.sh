set -eu
source $setupEnvPath
source $stdenvUtilsPath
NIX_SUPPORT_DIR="$out/nix-support"
NIX_FAILED_BUILD_FILE="$NIX_SUPPORT_DIR/failed"
HYDRA_BUILD_PRODUCTS_FILE="$NIX_SUPPORT_DIR/hydra-build-products"
LOG_DIR="$out/var/log"
DETAILED_BUILD_LOG="$LOG_DIR/$name-buildlog.txt"

TS_FORMAT="[%Y-%m-%d-%H:%M:%S]"

ensureNixSupportDir() {
    if [[ ! -d $NIX_SUPPORT_DIR ]]; then
        mkdir $NIX_SUPPORT_DIR
    fi
}

addHydraBuildProduct() {
    ensureNixSupportDir
    # the type and subtype specifically has to match:
    #   [a-zA-Z0-9_-]+
    # for now... just replace any space with "-"
    # and dots with "_"
    local type=$1
    local subtype=$2
    local path=$3
    type="$(echo $type | sed  -e 's/ /-/g' -e 's/\./_/g')"
    subtype="$(echo $subtype | sed -e 's/ /-/g' -e 's/\./_/g')"
    echo "$type $subtype \"$path\"" >> $HYDRA_BUILD_PRODUCTS_FILE
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

## add a log message to the build log using the
## same specific ts format
logMessage(){
    echo $* | ts $TS_FORMAT >> $DETAILED_BUILD_LOG
}

## add a log message to the build log without a date
logMessageWithoutTS(){
    echo $* >> $DETAILED_BUILD_LOG
}

# this will create the base directory structure and build log
mkdir -p $LOG_DIR && addHydraBuildProduct file log "$DETAILED_BUILD_LOG"

logMessageWithoutTS "STARTING BUILD '$name'"
logMessageWithoutTS "###############################################################################"
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>&>(ts $TS_FORMAT |
          sed -u 's;/nix/store/[a-zA-Z0-9]\{32,\};\<store-redacted\>;g' |
          tee -a $DETAILED_BUILD_LOG) 2>&1
set -v
source $scriptPath
set +v
# 1. Remove the 'source' line, (line number 3)
# 2. Remove the set +x line (last line)
sync && sed -e '3d' -e '$d' -i $DETAILED_BUILD_LOG
logMessageWithoutTS "###############################################################################"
logMessageWithoutTS "END OF BUILD '$name'"
# sed -e 's/^\(\[.\{19,\}\]\)[[:space:]]++[[:space:]]\(.*\)/\1 $ \2/g'
addHydraBuildProduct nix-build unholy $out
