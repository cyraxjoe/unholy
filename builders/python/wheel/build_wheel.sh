#!/bin/bash

# fail on first error or unset env variables
set -eu

echo "Beginning setup for building python wheel(s)"

WHEELDIR=/home/nixvoyager-user/wheel
RESULT=/home/nixvoyager-user/exports
VIRTUALENV_TAR=/home/nixvoyager-user/virtualenv
mkdir $RESULT
mkdir $WHEELDIR
mkdir $VIRTUALENV_TAR

# TODO: we should not assume --strip 1 here, but it works
# with all recent virtualenv distributions
cd $VIRTUALENV_TAR
tar -xf $NIXVOYAGER_ARG_virtualEnvSrc --strip 1
$systemPython $VIRTUALENV_TAR/virtualenv.py _env/
source _env/bin/activate


cd $WHEELDIR

for source_dist in $(echo $NIXVOYAGER_ARG_sources | tr ':' ' ')
do
  TMP_WHEEL_DIR=$(mktemp --directory --tmpdir="/tmp")

  cd $TMP_WHEEL_DIR
  if [ -d $source_dist ];
  then
    cp -r $source_dist/* $TMP_WHEEL_DIR;
  else
    cp $source_dist $TMP_WHEEL_DIR
  fi

  echo "Building wheel for source '${source_dist}'"

  # NOTE: we could use `$systemPython setup.py bdist_wheel` instead of pip wheel,
  # but pip has more helpful build options (such as --no-deps) and has been
  # consistent so far. it can also build .tar.gz sources without requiring
  # extra steps to untar and find the setup.py file.
  # this command will place the built `.whl` file into $RESULT
  pip wheel --no-index --no-deps $source_dist -v --wheel-dir $RESULT/

done
