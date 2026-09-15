#!/bin/sh
set -eu
GOPHER=${GOPHER:-gopher}
$GOPHER --profile tn5250-standards context tn5250-standards >/dev/null
$GOPHER --profile tn5250-standards search "RFC 4777" >/dev/null
$GOPHER --profile tn5250-standards search "printed physical page" >/dev/null
printf '%s\n' 'PASS tn5250 standards sphere retrieval smoke'
