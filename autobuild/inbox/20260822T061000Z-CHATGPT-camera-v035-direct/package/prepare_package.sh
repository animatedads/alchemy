#!/bin/sh
set -eu
rm -rf prepared
mkdir -p prepared/camera_behaviour_oorexx_v0.35
base64 -d camera_behaviour_oorexx_v0.35.zip.b64 > prepared/camera_behaviour_oorexx_v0.35.zip
unzip -q prepared/camera_behaviour_oorexx_v0.35.zip -d prepared/camera_behaviour_oorexx_v0.35
