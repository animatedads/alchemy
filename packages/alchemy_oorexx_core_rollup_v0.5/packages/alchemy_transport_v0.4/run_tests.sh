#!/bin/sh
set -eu
exec rexx "$(dirname "$0")/run_tests.rex"
