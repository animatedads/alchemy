#!/usr/bin/env bash
set -u
node=${1:-}
remote=${2:-}
[[ "$node" == ed209a ]] || exit 21
case "$remote" in
  'cat /proc/meminfo')
    printf '%s\n' \
      'MemTotal:        2000000 kB' \
      'MemAvailable:    1500000 kB' \
      'SwapTotal:        100000 kB' \
      'SwapFree:          75000 kB'
    ;;
  *)
    printf 'unsupported fake probe: %s\n' "$remote" >&2
    exit 22
    ;;
esac
