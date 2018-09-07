PROJECT_SRC="$(pwd)/project-src"
OUTPUT_BUILD_DIR=$out/usr/lib/$name
MAKE_VENV_SCRIPT=$out/bin/make-virtualenv-for-$name
DEP_DIR=$OUTPUT_BUILD_DIR/dependencies
REQUIREMENTS_SRC=$PROJECT_SRC/$ENV_REQUIREMENTS
REQUIREMENTS_OUT=$OUTPUT_BUILD_DIR/$(basename $ENV_REQUIREMENTS)
MAIN_WHEELS=$OUTPUT_BUILD_DIR/main-wheels.txt

mkdir $out/bin
mkdir -p $DEP_DIR
cp -R --no-preserve mode  $src $PROJECT_SRC
cp $REQUIREMENTS_SRC $REQUIREMENTS_OUT

virtualenv _env
PS1=build # define PS1, otherwise the virtualenv complains
source _env/bin/activate
pip install no-manylinux1
pip download  --no-cache-dir -d $DEP_DIR -r $REQUIREMENTS_OUT
# build the wheel for the project
pushd $PROJECT_SRC
python setup.py bdist_wheel
cp -R dist/*  $DEP_DIR
ls dist/ > $MAIN_WHEELS
popd
######

### Add the wheels as build products in hydra
for d in $DEP_DIR/*;  do
   if [[ ''${d##*.} == "whl" ]]; then
     ptype=python-wheel
   else
     ptype=python-source-package
   fi
   addHydraBuildProduct file $ptype "$d"
done
######

if [[ typeOfVEnv == "system" ]]; then
    set +eu # to avoid the debug messages of the script
    substitute $makeVirtualEnvScript  $MAKE_VENV_SCRIPT \
       --subst-var DEP_DIR \
       --subst-var MAIN_WHEELS \
       --subst-var-by REQUIREMENTS_FILE $REQUIREMENTS_OUT
    set -eu
else
    set +eu # to avoid the debug messages of the script
    substitute $makeVirtualEnvScript  $MAKE_VENV_SCRIPT \
       --subst-var DEP_DIR \
       --subst-var MAIN_WHEELS \
       --subst-var-by REQUIREMENTS_FILE $REQUIREMENTS_OUT \
       --subst-var-by VIRTUALENV "$(which virtualenv)"
    set -eu
fi

chmod +x $MAKE_VENV_SCRIPT
