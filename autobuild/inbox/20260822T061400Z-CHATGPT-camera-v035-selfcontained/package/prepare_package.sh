#!/bin/sh
set -eu
rm -rf prepared
mkdir -p prepared/camera_behaviour_oorexx_v0.35
cat camera_v035.b64.part-* | base64 -d > prepared/camera_behaviour_oorexx_v0.35.zip
unzip -q prepared/camera_behaviour_oorexx_v0.35.zip -d prepared/camera_behaviour_oorexx_v0.35
