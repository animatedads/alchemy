#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
mkdir -p "$ROOT/run/test"
AUTH="$ROOT/campaign/FCPAPHOS_ORIGINALS_SHA256SUMS"
EXPECTED=a168f7d82f603f8d1671a7debf5a3aaae4a71a9c33f10cf2d22bff2e5453fae9
got=$(sha256sum "$AUTH" | awk '{print $1}')
[ "$got" = "$EXPECTED" ] || { echo "FAIL authority sha expected=$EXPECTED got=$got" >&2; exit 1; }
[ "$(wc -l < "$AUTH" | tr -d ' ')" -eq 120 ] || { echo "FAIL authority line count" >&2; exit 1; }
awk '
  BEGIN { fc=0; fd=0; bad=0 }
  $1 !~ /^[0-9a-f]{64}$/ { bad++ }
  $2 ~ /^camera_fc\/.*_original[.]ogg$/ { fc++ }
  $2 ~ /^camera_fd\/.*_original[.]ogg$/ { fd++ }
  $2 !~ /^camera_f[cd]\/.*_original[.]ogg$/ { bad++ }
  END {
    if (bad || fc != 95 || fd != 25) {
      printf "FAIL authority shape fc=%d fd=%d bad=%d\n", fc, fd, bad > "/dev/stderr"
      exit 1
    }
    printf "PASS corpus authority fc=%d fd=%d entries=%d\n", fc, fd, fc+fd
  }
' "$AUTH"
sed -n 's#^[0-9a-f][0-9a-f]*  camera_fc/##p' "$AUTH" | sort > "$ROOT/run/test/auth_fc.txt"
sort "$ROOT/campaign/FC_FILES.txt" > "$ROOT/run/test/list_fc.txt"
cmp "$ROOT/run/test/auth_fc.txt" "$ROOT/run/test/list_fc.txt"
sed -n 's#^[0-9a-f][0-9a-f]*  camera_fd/##p' "$AUTH" | sort > "$ROOT/run/test/auth_fd.txt"
sort "$ROOT/campaign/FD_FILES.txt" > "$ROOT/run/test/list_fd.txt"
cmp "$ROOT/run/test/auth_fd.txt" "$ROOT/run/test/list_fd.txt"
echo "PASS corpus authority filenames"
