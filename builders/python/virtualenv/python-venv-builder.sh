#!/bin/bash
#########################################################
# Support functions
#########################################################

# zip two space space-separeted strings and "zip" them,
# in a line-break separated string.
# e.g.: _zipRequires "file_a file_b file_c" "dir_a dir_b https://foo/deps"
# Returns:
#     file_a
#     dir_a
#     file_b
#     dir_b
#     file_c
#     https://foo/deps
# This output is meant to be consumed by "read" calls
_zipRequires(){
    local files=$1
    local flinks=($2)
    local requires index=0
    # consume the output of this function
    # based on read name/read value;
    for requires in $files; do
        echo $requires
        echo "${flinks[index++]}"
    done
}

zipRequires(){
    _zipRequires "$requiresFiles" "$findLinks"
}

zipBuildRequires(){
    _zipRequires "$buildRequiresFiles" "$buildFindLinks"
}

ensureVarLog(){
    if [[ ! -d $out/var/log ]]; then
        mkdir $out/var/log
    fi
}

virtualEnv(){
    $systemPython $VENV_EXEC $*
}

pipWrapper(){
    $VENV_OUT_DIR/bin/pip --no-cache-dir $*
}

pipWrapperForWheels(){
    local build_log=$(mktemp)
    local pip_args="--no-cache-dir --log $build_log $*"
    $VENV_WHEEL_FACTORY/bin/pip $pip_args
    set +e
    if $(grep -q "Downloading" $build_log); then
        ensureVarLog
        local piplog_name="pip-$(basename $build_log).log"
        echo "===========================================" >> $IMPROVEMENTS
        echo "Some packages were downloaded as part of the wheel build process:" >> $IMPROVEMENTS
        # this awk is maybe a bit too much dependen on the pip log output,
        # update in case this message starts to get messed up and verify the
        # full pip log
        awk '/Downloading from URL/{print $5}'  $build_log | sort -u >> $IMPROVEMENTS
        echo "Try to make use of the 'requires' and 'buildRequires' arguments"  >> $IMPROVEMENTS
        echo "For more information see: var/log/$piplog_name"  >> $IMPROVEMENTS
        echo "pip args: '$pip_args'"  >> $IMPROVEMENTS
        echo "pip args: '$pip_args'" >> $build_log
        echo "==========================================="  >> $IMPROVEMENTS
        cp $build_log $out/var/log/$piplog_name
    fi
    set -e
}


pushWheel(){
    local pkgname=$1
    local name="${pkgname%-*}"
    local version="${pkgname##*-}"
    if [[ $name != $version ]]; then
        wheelsToInstall+=("${name}==${version}")
    else
        wheelsToInstall+=("$pkgname")
    fi
}

executeWithSystemPATH(){
    local ORG_PATH="$PATH"
    # modify the path, so that in case that is required it can find any system
    # config utility required for native executabels
    PATH="/usr/bin:$PATH"
    # TODO: trap the errors and guarantee some sanity on PATH
    $*
    PATH=$ORG_PATH
}

buildWheelsForPreloadedPythonDependencies(){
    ### build any directly provided dependencies
    echo $preLoadedPythonDeps | sed 's/ /\n/g' | {
        local pname src
        while read pname
        do
          read src
          echo "Building local dependency: $pname from $src"
          buildWheelFromSource  $pname $src
        done
    }
}

buildWheelFromSource(){
    local pname=$1 src=$2
    if [[ -d $src ]]; then # src is a diectory, copy it over and move into it
        cp -R --no-preserve mode $src ./$pname && pushd $pname
    else # assume is a tar.gz, extract and get in
        tar xzf $src && pushd $pname
    fi
    executeWithSystemPATH \
        pipWrapperForWheels wheel \
                           --isolated \
                           --wheel-dir $WHEELS_DIR . && pushWheel $pname
    popd > /dev/null
}

buildWheelsFromRequires(){
    local buildArgs=""
    if [[ -n $BUILD_DEPS ]]; then
        buildArgs="--only-binary \"$BUILD_DEPS\" --find-links $WHEELS_DIR"
    fi
    zipRequires | {
        local req findLinks
        while read req; do
            read findLinks
            executeWithSystemPATH \
                pipWrapperForWheels  wheel \
                  --no-binary ":all:" \
                  --find-links "$findLinks" \
                  --requirement "$req" \
                  --wheel-dir $WHEELS_DIR  $buildArgs

        done
    }
}


installWheels(){
    local name requirement
    for requirement in $requiresFiles; do
        pipWrapper install \
                   --no-index \
                   --find-links $WHEELS_DIR \
                   --only-binary ":all:" \
                   --requirement "$requirement"
    done
    # install the locally built wheels, those
    # provided either via the mainPackage method or
    # as a preloaded dependency
    for name in ${wheelsToInstall[@]}; do
        echo "Installing wheel for: $name"
        pipWrapper install \
                   --no-index \
                   --find-links $WHEELS_DIR \
                   --only-binary ":all:" \
                   "$name"
    done
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
    set +e # allow errors
    # (actually the error will occur only if lsb_release works as expected)
    if (! lsb_release --all 2>/dev/null ); then
        echo "Unable to obtain the system information, lsb_release was not available."
    fi
    set -e # get back to the strict evaluation
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
    pipWrapper freeze
}

obtainPythonVersion(){
    $VENV_OUT_DIR/bin/python --version 2>&1
}


# install any build dependencies, anything necessary ONLY
# to build the wheels, but not the final virtual environment,
# good example are setuptools, setuptools_scm, wheel, etc.
setupWheelFactory(){
    echo "Setting up the wheel factory."
    zipBuildRequires | {
        local req findLinks
        # use the pip from the venv for the wheel building
        # without any wrapper, there is no eral need to do so.
        # Note that we are _always_ not using the pypi index
        while read req; do
            read findLinks
            # build the wheels required for the build of the actual application
            $VENV_WHEEL_FACTORY/bin/pip wheel \
                                        --no-cache-dir \
                                        --no-index \
                                        --find-links "$findLinks" \
                                        --requirement "$req" \
                                        --wheel-dir $WHEELS_DIR
            # install the wheel that were built in the previous step,
            # the connection between the two is done over the --wheel-dir -> --find-links
            # relationship in both calls
            $VENV_WHEEL_FACTORY/bin/pip install \
                                        --no-cache-dir \
                                        --no-index \
                                        --find-links $WHEELS_DIR \
                                        --requirement "$req"
        done
    }
    echo "DONE"
}



#########################################################
# End of support functions
#########################################################
# array to be used to determine all the wheels
# that are going to be installed, in addition to the ones
# defined in the requires files
declare -a wheelsToInstall
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
IMPROVEMENTS="$PWD/improvements.txt"
VENV_WHEEL_FACTORY="$PWD/wheel_factory"
WHEELS_DIR="$PWD/wheels"
VENV_SYSTEM_INFO_FILE="$VENV_OUT_DIR/system_info.txt"
EXECUTABLES_IN_VENV_FILE="$VENV_OUT_DIR/native_executables.txt"
VENV_REQUIREMENTS_FILE="$VENV_OUT_DIR/requirements.txt"
PYTHON_VERSION_FILE="$VENV_OUT_DIR/python_version.txt"
################################################################
## create the virtualenv
virtualEnv $VENV_OUT_DIR
mkdir $WHEELS_DIR
# create a virtualenv to be used only to create the wheels that
# are going to be installed in the final virtualenv
virtualEnv $VENV_WHEEL_FACTORY
if [[ -n $buildRequiresFiles ]]; then
    setupWheelFactory
    # get a comma separeted list of the wheels that were built/installed
    # in the "wheel factory" virtualenv, these will be used to
    # be passed as "--only-binary".
    #
    # All of this is required because we are building the wheels for all the
    # applications dependencies, to do so, we might need some extra dependencies
    # not relevant for the resulting virtualenv, but required for the build
    # process.
    BUILD_DEPS="$($VENV_WHEEL_FACTORY/bin/pip list  | tail -n +3 | awk -v ORS="," '{print($1)}')"
else
    BUILD_DEPS=""
fi
##################


### build all the wheels!!
if [[ -n $requiresFiles ]]; then
    buildWheelsFromRequires
fi

if [[ -n $preLoadedPythonDeps ]]; then
    buildWheelsForPreloadedPythonDependencies
fi

if [[ -n $mainPackageName ]] && [[ -n $mainPackageSrc ]];then
    buildWheelFromSource $mainPackageName $mainPackageSrc
fi
echo "List of generated wheels:"
ls -l $WHEELS_DIR
##################
installWheels
###############
exposeCmdsFromEnv
#############
#  Extra information about the build
##########
obtainSystemInfo > "$VENV_SYSTEM_INFO_FILE"
obtainNativeExecutables > "$EXECUTABLES_IN_VENV_FILE"
obtainRequiremens > "$VENV_REQUIREMENTS_FILE"
obtainPythonVersion > "$PYTHON_VERSION_FILE"
# copy over the wheels into the wheels output
cp -r $WHEELS_DIR/* $wheels

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

if [[ -e $IMPROVEMENTS ]]; then
    echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    cat $IMPROVEMENTS
    echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
else
    echo "****************************************************"
    echo " Great work! There are no recommended improvements."
    echo "****************************************************"
fi
