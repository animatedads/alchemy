#!/bin/sh
set -eu
rm -rf prepared/camera_behaviour_oorexx_v0.35
mkdir -p prepared/camera_behaviour_oorexx_v0.35
cp -a "${LIVE_CAMERA_ROOT}"/. prepared/camera_behaviour_oorexx_v0.35/
