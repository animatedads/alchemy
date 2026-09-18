#!/bin/sh
set -eu
node tests/node_semantics.js
node tests/bidirectional_semantics.js
./build-native.sh
./build/native_crossing
DUKTAPE_LIB=${DUKTAPE_LIB:-/lib/x86_64-linux-gnu/libduktape.so.207} ./build-engine.sh
./build/inprocess_nested_identity
python3 tests/cooperative_interposition_contract.py
node tests/semantic_target_fixture.js
