#!/usr/bin/env sh
set -eu
base=30e1d483ea62c8805efc6c926cc07f0c5f3d29252de4d97dff7a4ff2be613ad2
actual=$(sha256sum bundyslam-corpus-v0.2.zip | cut -d ' ' -f 1)
test "$actual" = "$base" || { echo 'ERROR: prior v0.2 ZIP hash mismatch' >&2; exit 1; }
unzip -qo bundyslam-corpus-v0.2.zip
mv bundyslam-corpus-v0.2 bundyslam-corpus-v0.2.1
(cd bundyslam-corpus-v0.2.1 && patch -s -p1 < ../bundyslam-v0.2.1.patch)
cp DEV3.md bundyslam-corpus-v0.2.1/docs/DEV3.md
sed -i '1s/v0\.2$/v0.2.1/' bundyslam-corpus-v0.2.1/README.md
sed -i 's/See `docs/DEV2.md` for exact qualification limits\./See `docs/DEV2.md` and `docs/DEV3.md` for exact qualification limits and the new continuation precedence regression./' bundyslam-corpus-v0.2.1/README.md
(
  cd bundyslam-corpus-v0.2.1
  find . -type f ! -name MANIFEST.sha256 -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sed 's|  ./|  |' > MANIFEST.sha256
  sha256sum -c MANIFEST.sha256 >/dev/null
  sh run_qualification.sh
)
