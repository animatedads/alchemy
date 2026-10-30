#!/bin/sh
set -eu
cd "$(dirname "$0")"
python3 tests/test_wav_query.py
python3 tests/test_render_matches.py
python3 tests/test_review_feedback.py
python3 tests/test_v7_validate.py
python3 tests/test_v7_scan.py
