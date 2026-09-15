#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
: "${REXX_PATH:?REXX_PATH must include src, package root, Foreign Runtime rexx, and ooRexx bin}"
rexxc src/FCVehicleMotion.cls /tmp/FCVehicleMotion.cls.img
(
  cd tests
  rexx test_fc_vehicle_motion_logic.rex
  rexx test_fc_vehicle_motion_output.rex
  rexx test_fc_camera_qualification_tsv.rex
)
