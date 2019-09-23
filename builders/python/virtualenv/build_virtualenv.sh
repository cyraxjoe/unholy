#!/bin/bash

# fail on first error or unset env variables
set -eu

echo "Beginning setup for virtualenv build"
VIRTUALENV_TAR=/home/nixvoyager-user/virtualenv
RESULT=/home/nixvoyager-user/exports

mkdir $VIRTUALENV_TAR
mkdir $RESULT

# TODO: we should not assume --strip 1 here, but it works
# with all recent virtualenv distributions
cd $VIRTUALENV_TAR
tar -xf $NIXVOYAGER_ARG_virtualEnvSrc --strip 1
$systemPython $VIRTUALENV_TAR/virtualenv.py $RESULT/
source $RESULT/bin/activate

# installs all the wheels from deps.nix
for wheel in $(ls $NIXVOYAGER_ARG_pythonDependencies); do
  echo "pip installing ${wheel}"
  pip install --no-index --no-deps $NIXVOYAGER_ARG_pythonDependencies/$wheel;
done

# patch up the paths so they don't refer to /home/nixvoyager-user
echo "Wheels isntalled. Running --relocatable in virtualenv '${RESULT}''"
$systemPython $VIRTUALENV_TAR/virtualenv.py $RESULT/ --relocatable
