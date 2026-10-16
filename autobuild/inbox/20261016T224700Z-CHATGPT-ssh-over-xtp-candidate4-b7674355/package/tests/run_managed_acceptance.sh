#!/bin/sh
set -eu
make clean all
timeout 75s bash tests/test_loopback.sh
timeout 35s python3 tests/test_policy.py
timeout 75s python3 tests/test_service_admission.py
