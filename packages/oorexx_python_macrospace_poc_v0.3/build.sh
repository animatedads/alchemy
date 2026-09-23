#!/bin/sh
set -eu
: "${OOREXX_PREFIX:=/usr/local}"
CXX=${CXX:-g++}
EXT=$(python3-config --extension-suffix)
$CXX -O2 -fPIC -shared $(python3-config --includes) -I"$OOREXX_PREFIX/include" native/rexxpython_poc.cpp \
  -L"$OOREXX_PREFIX/lib" -Wl,-rpath,"$OOREXX_PREFIX/lib" -lrexxapi -lrexx -o "python/_rexxpython_poc$EXT"
echo "built python/_rexxpython_poc$EXT"
