#!/usr/bin/env bash
set -euo pipefail
pkg_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(cd "$pkg_dir/../.." && pwd)"
spash_dir="$repo_dir/packages/oorexx_spash_challenger_v0.1-dev1/native_audio/seek"
: "${FOREIGN_RUNTIME_LIB_DIR:?set the directory containing libforeign_runtime.so}"
: "${FOREIGN_REXX_DIR:?set the directory containing foreign.cls}"
out_dir="$(mktemp -d)"
cc -O2 -std=c11 -Wall -Wextra -Werror -fPIC -shared "$pkg_dir/media_spectrum_fft.c" -lm -o "$pkg_dir/libmedia_spectrum.so"
cc -O2 -std=c11 -Wall -Wextra -Werror "$pkg_dir/tests/generate_tone.c" -lm -o "$out_dir/generate_tone"
"$out_dir/generate_tone" "$out_dir/tone.f32"
LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB_DIR:${LD_LIBRARY_PATH:-}" \
REXX_PATH="$pkg_dir:$spash_dir:$FOREIGN_REXX_DIR:${REXX_PATH:-}" \
rexx "$pkg_dir/tests/test_tone.rex" "$pkg_dir/media_spectrum.bridge.json" "$out_dir"
printf 'Synthetic receipt: %s/receipt.tsv\n' "$out_dir"
