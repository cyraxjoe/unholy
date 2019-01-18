
### setup virtualenv
tar xvzf $virtualEnvTar | tee untar.log
VENV_EXEC=$(readlink -e $(head -n 1 untar.log)/virtualenv.py)
VENV_OUT_DIR=$out/envs/$name
rm untar.log
mkdir $out/envs

virtualenv(){
    $systemPython  $VENV_EXEC $*
}

###
## create the virtualenv
virtualenv $VENV_OUT_DIR


installPythonPackage(){
    set -x
    local pname=$1
    local src=$2
    set +u
    local requires_deps="$3"
    set -u
    if [[ -d $src ]]; then
        cp -R --no-preserve mode $src ./$pname && pushd $pname
    else
        tar xvzf $src && pushd $pname
    fi
    ORG_PATH="$PATH"
    PATH="/usr/bin:$PATH"
    if [[ -n $requires_deps ]]; then
        # remove any "-e" dependencies
        # those should be provided as an element in the
        # preLoadedPythonDeps list
        sed -i '/^-e.*/d' $requires_deps
        $VENV_OUT_DIR/bin/pip  --no-cache-dir --isolated install -r $requires_deps
        $VENV_OUT_DIR/bin/pip  --no-cache-dir --isolated install --no-index .
    else
        $VENV_OUT_DIR/bin/pip --isolated --no-cache-dir  install .
    fi
    PATH=$ORG_PATH
    popd
    set +x
}

installPythonDependencies(){
    local pname=
    local src=
    if [[ -n "$preLoadedPythonDeps" ]]; then
        ### install any directly provided dependencies
        echo $preLoadedPythonDeps | sed 's/ /\n/g' | {
          read pname
          read src
          echo "Installing local dependency: $pname from $src"
          installPythonPackage $pname $src
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

if [[ -z $useBinaryWheels ]]; then
    # exclude the manylinux wheels
    # by installing no-manylinux (or we could just put the flag)
    $VENV_OUT_DIR/bin/pip --isolated --no-cache-dir install no-manylinux1
fi

######################
installPythonDependencies
# Main Package
installPythonPackage $mainPackageName $src "$installDepsFromRequires"
exposeCmdsFromEnv

#############
#  Extra information about the build
##########
venv_system_info=$VENV_OUT_DIR/system_info.txt
executables_in_venv=$VENV_OUT_DIR/native_executables.txt
venv_requirements=$VENV_OUT_DIR/requirements.txt
python_version_file=$VENV_OUT_DIR/python_version.txt
# record the LSB release information
lsb_release --all > $venv_system_info
###
##
# detect which executables are we delivering with the package
for file_in_out in $(find  "$out" -type f  -executable  -or -name '*.so'); do
    if [[ $(file -b  $file_in_out | grep ELF) ]]; then
        echo "################################################################"
        echo $file_in_out
        ldd $file_in_out
    fi
done > $executables_in_venv
#######
$VENV_OUT_DIR/bin/pip freeze --all > $venv_requirements
$VENV_OUT_DIR/bin/python --version >  $python_version_file

addHydraBuildProduct doc "System Infomation" $venv_system_info
addHydraBuildProduct doc "Executables"  $executables_in_venv
addHydraBuildProduct doc "Requirements" $venv_requirements
addHydraBuildProduct doc "Python version" $python_version_file
