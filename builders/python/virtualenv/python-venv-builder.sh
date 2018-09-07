
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
    local name=$1
    local src=$2
    if [[ -d $src ]]; then
        cp -R --no-preserve mode $src ./$name && pushd ./$name
    else
        tar xvzf $src && pushd ./$name
    fi
    $VENV_OUT_DIR/bin/pip --isolated --no-cache-dir install .
    popd
    set +x
}

installPythonDependencies(){
    local name=
    local src=
    if [[ -n "$preLoadedPythonDeps" ]]; then
        ### install any directly provided dependencies
        echo $preLoadedPythonDeps | sed 's/ /\n/g' | {
          read name
          read src
          echo "Installing local dependency: $name from $src"
          installPythonPackage $name $src
          while read name
          do
            read src
            echo "Installing local dependency: $name from $src"
            installPythonPackage $name $src
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

######################
installPythonDependencies
# Main Package
installPythonPackage $name $src
exposeCmdsFromEnv
lsb_release --all > $VENV_OUT_DIR/env.system.info
