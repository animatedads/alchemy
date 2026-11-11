#!/bin/sh
set -eu
cd "$(dirname "$0")"
cc=${CC:-gcc}
"$cc" -std=c11 -O3 -fPIC -Wall -Wextra -Werror -shared -o libav9_spatial_provider.so av9_spatial_provider.c -lm
sha256sum libav9_spatial_provider.so
