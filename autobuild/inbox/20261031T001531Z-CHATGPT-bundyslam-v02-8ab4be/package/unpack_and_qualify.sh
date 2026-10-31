#!/usr/bin/env sh
set -eu
unzip -qo bundyslam-corpus-v0.2.zip
cp integration.json bundyslam-corpus-v0.2/integration.json
cp GIT_SOURCE.md bundyslam-corpus-v0.2/GIT_SOURCE.md
cd bundyslam-corpus-v0.2
sh run_qualification.sh
