#!/bin/sh
set -eu
: "${OOREXX_HOME:?set OOREXX_HOME to ooRexx prefix}"
: "${JS_ALCHEMY_HOME:?set JS_ALCHEMY_HOME to JavaScript Alchemy dev23 root}"
: "${PROLOG_ALCHEMY_HOME:?set PROLOG_ALCHEMY_HOME to Prolog Alchemy dev13 root}"
: "${ALCHEMY_FOREIGN_PATH:?set ALCHEMY_FOREIGN_PATH to directory containing AlchemyForeignObject.cls}"
: "${ALCHEMY_OBJECTS_PATH:?set ALCHEMY_OBJECTS_PATH to Alchemy Objects src directory}"
: "${ALCHEMY_DEP_PATHS:?set ALCHEMY_DEP_PATHS to remaining Alchemy dependency Rexx paths}"
: "${QUICKJS_LIB:?set QUICKJS_LIB to QuickJS-NG library directory}"
SWI_HOME="${SWI_HOME_DIR:-$PROLOG_ALCHEMY_HOME/swipl/lib/swipl}"
export SWI_HOME_DIR="$SWI_HOME"
export LD_LIBRARY_PATH="$JS_ALCHEMY_HOME/build:$PROLOG_ALCHEMY_HOME/lib:$SWI_HOME/lib/x86_64-linux:$OOREXX_HOME/lib:$QUICKJS_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$JS_ALCHEMY_HOME/rexx:$PROLOG_ALCHEMY_HOME/src:$ALCHEMY_FOREIGN_PATH:$ALCHEMY_OBJECTS_PATH:$OOREXX_HOME/bin:$ALCHEMY_DEP_PATHS:$PWD/rexx${REXX_PATH:+:$REXX_PATH}"
"$OOREXX_HOME/bin/rexx" tests/test_three_language_composition.rex "$PWD/tests/three_language/mail_rules.pl"
