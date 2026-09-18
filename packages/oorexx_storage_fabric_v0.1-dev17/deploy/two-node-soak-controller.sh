#!/usr/bin/env bash
set -euo pipefail
# Launch an already-installed soak on two hosts.  No hostnames are baked in:
# choose any two ED209 nodes at qualification time.
A=${1:?usage: two-node-soak-controller.sh SSH_TARGET_A SSH_TARGET_B [REMOTE_ROOT] [MOUNT]}
B=${2:?usage: two-node-soak-controller.sh SSH_TARGET_A SSH_TARGET_B [REMOTE_ROOT] [MOUNT]}
ROOT=${3:-~/oorexx_storage_fabric_v0.1-dev12}
MOUNT=${4:-/tmp/oorexx-storage}
for host in "$A" "$B"; do
  ssh "$host" "cd $ROOT && nohup deploy/fuse-soak.sh '$MOUNT' 0 > /tmp/storage-fuse-soak.stdout 2>&1 < /dev/null & echo \\$!"
done