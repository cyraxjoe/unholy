#!/bin/bash

# fail on first error
set -e

# TODOS: there's an assumption that the virtualenv and main sources will
# be tar'd inside a top-level folder. this could be made configurable or possibly
# detected.


WHEELDIR=/home/unholy-user/wheel
RESULT=/home/unholy-user/exports
VIRTUALENV_TAR=/home/unholy-user/virtualenv
mkdir $RESULT
mkdir $WHEELDIR
mkdir $VIRTUALENV_TAR

cd $VIRTUALENV_TAR
tar -xvf $UNHOLY_ARG_virtualEnvSrc --strip 1
$PYTHON_BIN $VIRTUALENV_TAR/virtualenv.py _env/
source _env/bin/activate


cd $WHEELDIR

if [ -d $UNHOLY_ARG_source ];
then
  cp -r $UNHOLY_ARG_source/* $WHEELDIR;
else
  tar -C $WHEELDIR -xvf $UNHOLY_ARG_source --strip 1;
fi

cd $WHEELDIR/

python setup.py bdist_wheel -vv

# copying the `.whl` file to the result dir
cp dist/* $RESULT/
