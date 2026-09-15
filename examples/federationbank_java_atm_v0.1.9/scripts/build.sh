#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build/classes
mkdir -p build/classes
find src/main/java -name '*.java' -print0 | xargs -0 javac --release 17 -Xlint:all -d build/classes
printf 'Main-Class: com.federationbank.atm.Main\nImplementation-Title: FederationBank Java ATM\nImplementation-Version: 0.1.9\n' > build/MANIFEST.MF
jar cfm build/federationbank-atm.jar build/MANIFEST.MF -C build/classes .
echo "built build/federationbank-atm.jar"
