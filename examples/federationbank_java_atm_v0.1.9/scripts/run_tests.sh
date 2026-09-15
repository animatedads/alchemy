#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build/test-classes build/classes
mkdir -p build/classes build/test-classes
find src/main/java -name '*.java' -print0 | xargs -0 javac --release 17 -Xlint:all -d build/classes
find src/test/java -name '*.java' -print0 | xargs -0 javac --release 17 -Xlint:all -cp build/classes -d build/test-classes
java -ea -cp build/classes:build/test-classes com.federationbank.atm.AtmTestSuite
