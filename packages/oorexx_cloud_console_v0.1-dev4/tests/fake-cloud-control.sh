#!/bin/sh
set -eu
if [ -n "${CLOUDCTL_FAKE_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$CLOUDCTL_FAKE_LOG"
fi
printf '%s\n' '{"fake":"alchemy-cloud-control-ok"}'
