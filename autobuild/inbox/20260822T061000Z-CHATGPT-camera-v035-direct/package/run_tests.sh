#!/bin/sh
set -eu
cd prepared/camera_behaviour_oorexx_v0.35
for f in CameraCore.cls test_*.rex; do rexxc "$f" >/dev/null; done
rm -f ./*.orx
for f in test_*.rex; do rexx "$f"; done
rm -f ./*.orx
