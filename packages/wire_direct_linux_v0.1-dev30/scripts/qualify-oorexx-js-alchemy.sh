#!/bin/sh
set -eu
: "${OOREXX_HOME:?set OOREXX_HOME to ooRexx prefix}"
: "${JS_ALCHEMY_HOME:?set JS_ALCHEMY_HOME to JavaScript Alchemy dev23 root}"
: "${QUICKJS_LIB:?set QUICKJS_LIB to QuickJS-NG build/lib directory}"
: "${ALCHEMY_FOREIGN_PATH:?set ALCHEMY_FOREIGN_PATH to directory containing AlchemyForeignObject.cls}"
: "${ALCHEMY_OBJECTS_PATH:?set ALCHEMY_OBJECTS_PATH to Alchemy Objects src directory}"
CXX=${CXX:-c++}; CC=${CC:-cc}
mkdir -p build
$CC -std=c11 -Wall -Wextra -Werror -fPIC -Iinclude -c src/wire_test_renderer.c -o build/wire_test_renderer.o
$CXX -std=c++17 -Wall -Wextra -Werror -fPIC -I"$OOREXX_HOME/include" -Iinclude -c tests/wire_oorexx_renderer_package.cpp -o build/wire_oorexx_renderer_package.o
$CXX -shared build/wire_oorexx_renderer_package.o build/wire_test_renderer.o -L"$OOREXX_HOME/lib" -lrexx -o build/libwire_oorexx_renderer_package.so
export LD_LIBRARY_PATH="$PWD/build:$JS_ALCHEMY_HOME/build:$OOREXX_HOME/lib:$QUICKJS_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$JS_ALCHEMY_HOME/rexx:$ALCHEMY_FOREIGN_PATH:$ALCHEMY_OBJECTS_PATH:$PWD/rexx${REXX_PATH:+:$REXX_PATH}"
"$OOREXX_HOME/bin/rexx" tests/test_oorexx_javascript_alchemy_filter.rex
