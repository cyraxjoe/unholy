#/usr/bin/env bash
if [[ -z $1 ]]; then
    echo "Missing virtualenv executable as first argument" > /dev/stderr
    exit 1
elif [[ -z $2 ]]; then
    echo "Missing python interpreter as second argument" > /dev/stderr
    exit 1
elif [[ -z $3 ]]; then
    echo "Missing virtualenv target dir as third argument" > /dev/stderr
    exit 1
fi

VENV=$1
PYTHON=$2
TARGET_DIR=$3
$VENV -p $PYTHON $TARGET_DIR
source $TARGET_DIR/bin/activate
#pip install --no-index --no-cache-dir --find-links @DEP_DIR@ -r @REQUIREMENTS_FILE@
while read wheel; do
    pip install --no-index --find-links @DEP_DIR@ --no-cache-dir @DEP_DIR@/$wheel
done < @MAIN_WHEELS@
