#!/bin/sh
# Rebuilds app.res and app.dll from app.rc.  Needs llvm-rc and lld-link
# (LLVM 18 was used).  The built files are committed, so the tests do not
# need LLVM.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
set -eu
cd "$(dirname "$0")"
INC=${WIN_SDK_INCLUDE:-$(pwd)/include}
llvm-rc /nologo /C 65001 /I "$INC" /FO app.res app.rc
lld-link /nologo /dll /noentry /machine:x64 /out:app.dll app.res
rm -f app.lib
sha256sum app.rc app.res app.dll > SHA256SUMS
