#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
pkg=$(cd "$here/.." && pwd)
cc=${CC:-gcc}
command -v "$cc" >/dev/null 2>&1 || { echo 'FAIL C compiler required for ABI-profile qualification' >&2; exit 2; }
probe="$here/.abi_profile_probe.$$"
out="$here/.abi_profile_probe.$$.out"
trap 'rm -f "$probe" "$out"' EXIT
"$cc" -std=gnu11 -Wall -Wextra -Werror -O2 "$here/abi_profile_probe.c" -o "$probe"
"$probe" > "$out"
python3 "$here/verify_abi_profile.py" "$pkg/bridge/libc-af-unix.bridge.json" "$out"
