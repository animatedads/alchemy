#!/bin/sh
set -eu
cd "$(dirname "$0")"
rm -rf prepared _unpack
mkdir -p prepared/msqlshim_v0.14

if [ -f "${LIVE_MSQLSHIM_ROOT}/README.md" ] && grep -q 'msqlshim v0\.14' "${LIVE_MSQLSHIM_ROOT}/README.md"; then
  echo "Using live msqlshim v0.14 source: ${LIVE_MSQLSHIM_ROOT}"
  cp -a "${LIVE_MSQLSHIM_ROOT}"/. prepared/msqlshim_v0.14/
else
  archive=$(find "${DOWNLOADS_ROOT}" -maxdepth 1 -type f -name 'msqlshim_v0.14*.zip' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)
  if [ -z "$archive" ]; then
    echo "No msqlshim v0.14 live source and no msqlshim_v0.14*.zip in ${DOWNLOADS_ROOT}." >&2
    if [ -f "${LIVE_MSQLSHIM_ROOT}/README.md" ]; then
      echo "Live README begins:" >&2
      sed -n '1,8p' "${LIVE_MSQLSHIM_ROOT}/README.md" >&2
    fi
    exit 1
  fi
  echo "Using downloaded archive: $archive"
  mkdir _unpack
  unzip -q "$archive" -d _unpack
  root=$(find _unpack -type f -name README.md -path '*/msqlshim_v0.14/README.md' -printf '%h\n' | head -1)
  test -n "$root"
  grep -q 'msqlshim v0\.14' "$root/README.md"
  cp -a "$root"/. prepared/msqlshim_v0.14/
fi

test -f prepared/msqlshim_v0.14/src/MySQLWireServer.cls
test -f prepared/msqlshim_v0.14/src/MySQLDeflate.cls
test -f prepared/msqlshim_v0.14/run_tests.sh
# Preserve the candidate exactly enough for its manifest/self-tests; only discard Python cache files.
find prepared/msqlshim_v0.14 -type d -name __pycache__ -prune -exec rm -rf {} +
find prepared/msqlshim_v0.14 -type f -name '*.pyc' -delete
