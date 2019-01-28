#!/bin/bash
#########################################################
# Support functions
#########################################################

virtualEnv(){
    $systemPython $VENV_EXEC $*
}

pipWrapper(){
    $VENV_OUT_DIR/bin/pip --cache-dir "$CACHE_DIR" $*
}

installPythonPackage(){
    local pname=$1
    local src=$2
    set +u # $3 might not be defined
    local requires_deps="$3"
    set -u
    if [[ -d $src ]]; then # src is a diectory, copy it over and move into it
        cp -R --no-preserve mode $src ./$pname && pushd $pname
    else # assume is a tar.gz, extract and get in
        tar xzf $src && pushd $pname
    fi
    ORG_PATH="$PATH"
    # modify the path, so that in case that is required it can find any system
    # config utility required for native executabels
    PATH="/usr/bin:$PATH"
    if [[ -n $requires_deps ]]; then
        # remove any "-e" dependencies
        # those should be provided as an element in the
        # preLoadedPythonDeps list
        sed -i '/^-e.*/d' $requires_deps
        pipWrapper --isolated install -r $requires_deps
        pipWrapper --isolated install --no-index .
    else
        pipWrapper --isolated install .
    fi
    PATH=$ORG_PATH
    popd
}

installPythonDependencies(){
    if [[ -n "$preLoadedPythonDeps" ]]; then
        ### install any directly provided dependencies
        echo $preLoadedPythonDeps | sed 's/ /\n/g' | {
            local pname
            local src
            while read pname
            do
              read src
              echo "Installing local dependency: $pname from $src"
              installPythonPackage $pname $src
            done
        }
    fi
}

exposeCmdsFromEnv(){
    if [[ -n "$exposedCmds" ]]; then
        mkdir $out/bin
        for cmd in $exposedCmds; do
            ln -s $VENV_OUT_DIR/bin/$cmd $out/bin/$cmd
        done
    fi
}

topDirNameInTar(){
    tar -tzf $1 2>/dev/null | head -1 | cut -f1 -d"/"
}

isExternalBuild(){
    # when the storePath is defined, we assume this is
    # some sort of external build
    set +u # to test the storePath variable
    if [[ -z "$storePath" ]]; then
        set -u # revert the +u
        return 1
    else
        set -u # revert the +u
        return 0
    fi
}

executablesInVEnv(){
    find  "$VENV_OUT_DIR" -type f  -executable  -or -name '*.so'
}

obtainSystemInfo(){
    lsb_release --all
}

obtainNativeExecutables(){
    # detect which executables are we delivering with the package
    for file_in_out in $(executablesInVEnv); do
        if [[ $(file -b  $file_in_out | grep ELF) ]]; then
            echo "################################################################"
            echo $file_in_out
            ldd $file_in_out
        fi
    done
}

obtainRequiremens(){
    pipWrapper freeze --all
}

obtainPythonVersion(){
    $VENV_OUT_DIR/bin/python --version 2>&1

}

#########################################################
# End of support functions
#########################################################

# define a cache dir becase newer versions of pip + wheel doesn't
# work if you don't define one (or use the default in the $HOME)
CACHE_DIR=$(pwd)
### setup virtualenv
virtual_env_dir=$(topDirNameInTar $virtualEnvTar)
tar xzf $virtualEnvTar
VENV_EXEC=$(readlink -e "${virtual_env_dir}/virtualenv.py")
###
if isExternalBuild; then
    # make the external store path
    # this is a rather.. sad hack on the nix store,
    # but you know.. you're pretty unholy at this point
    mkdir -p $storePath/envs
    VENV_OUT_DIR=$storePath/envs/$name
else
    # regular local build
    mkdir $out/envs
    VENV_OUT_DIR=$out/envs/$name
fi
VENV_SYSTEM_INFO_FILE="$VENV_OUT_DIR/system_info.txt"
EXECUTABLES_IN_VENV_FILE="$VENV_OUT_DIR/native_executables.txt"
VENV_REQUIREMENTS_FILE="$VENV_OUT_DIR/requirements.txt"
PYTHON_VERSION_FILE="$VENV_OUT_DIR/python_version.txt"
################################################################
## create the virtualenv
virtualEnv $VENV_OUT_DIR
if [[ -z $useBinaryWheels ]]; then
    # exclude the manylinux wheels
    # by installing no-manylinux (or we could just put the flag)
    pipWrapper --isolated  install no-manylinux1
fi
######################
installPythonDependencies
# Main Package
installPythonPackage $mainPackageName $src "$installDepsFromRequires"
exposeCmdsFromEnv
#############
#  Extra information about the build
##########
obtainSystemInfo > "$VENV_SYSTEM_INFO_FILE"
obtainNativeExecutables > "$EXECUTABLES_IN_VENV_FILE"
obtainRequiremens > "$VENV_REQUIREMENTS_FILE"
obtainPythonVersion > "$PYTHON_VERSION_FILE"
if isExternalBuild; then
    # extract the virtualenv from the $storePath
    # and remove the path from the nix store,
    # the path is irrelevant for this nix store
    mkdir $out/envs
    mv $VENV_OUT_DIR $out/envs/$name
    rm -rf $storePath
fi
addHydraBuildProduct doc "System Infomation" $VENV_SYSTEM_INFO_FILE
addHydraBuildProduct doc "Executables"  $EXECUTABLES_IN_VENV_FILE
addHydraBuildProduct doc "Requirements" $VENV_REQUIREMENTS_FILE
addHydraBuildProduct doc "Python version" $PYTHON_VERSION_FILE
