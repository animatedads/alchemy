#!/bin/sh
set -eu
account=$1; shift
case "$account" in animated-ads-cy|bashqueue) ;; *) exit 3;; esac
exec gcloud "$@"
