#/usr/bin/env bash
if [[ -z $1 ]]; then
    echo "Missing python interpreter as first argument" > /dev/stderr
    exit 1
elif [[ -z $2 ]]; then
    echo "Missing virtualenv target dir as second argument" > /dev/stderr
    exit 1
fi

PYTHON=$1
TARGET_DIR=$2

@VIRTUALENV@ -p $PYTHON $TARGET_DIR
source $TARGET_DIR/bin/activate
pip install --no-index --no-cache-dir --find-links @DEP_DIR@ -r @REQUIREMENTS_FILE@
while read wheel; do
    pip install --no-index --find-links @DEP_DIR@ --no-cache-dir @DEP_DIR@/$wheel
done < @MAIN_WHEELS@
