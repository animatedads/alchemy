#!/bin/sh
set -eu
cd "$(dirname "$0")"
python3 tests/test_wav_query.py
python3 tests/test_render_matches.py
