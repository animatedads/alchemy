#!/usr/bin/env bash
set -euo pipefail
: "${REXX:=rexx}"
: "${REXXC:=rexxc}"
: "${MEMORY_FABRIC_SRC:?set MEMORY_FABRIC_SRC to Memory Fabric dev10 src}"
: "${CLUSTER_OBJECT_SRC:?set CLUSTER_OBJECT_SRC to Cluster Object Memory Fabric v0.2 src}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to Queue Fabric source directory}"
: "${AUDIO_V9_SRC:?set AUDIO_V9_SRC to Audio V9 candidate19 src}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/audio-v9-candidate20-$$
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"
cp "$ROOT/src/AudioV9MemoryHorizonExecution.cls" "$TMP/"
cp "$ROOT/tests/test_audio_v9_memory_horizon_execution.rex" "$TMP/"
cp "$MEMORY_FABRIC_SRC/MemoryFabric.cls" "$TMP/"
cp "$MEMORY_FABRIC_SRC/MemoryFabricSparseArray.cls" "$TMP/"
cp "$CLUSTER_OBJECT_SRC/ClusterObjectMemoryFabricTransport.cls" "$TMP/"
cp "$QUEUE_FABRIC_SRC/ObjectQueueFabric.cls" "$TMP/"
cp "$QUEUE_FABRIC_SRC/ObjectQueueChannels.cls" "$TMP/"
cp "$QUEUE_FABRIC_SRC/ObjectQueueCrypto.cls" "$TMP/"
cp "$AUDIO_V9_SRC/AudioV9ExecutionIntegration.cls" "$TMP/"
(
  cd "$TMP"
  "$REXXC" AudioV9MemoryHorizonExecution.cls
  "$REXXC" test_audio_v9_memory_horizon_execution.rex
  "$REXX" test_audio_v9_memory_horizon_execution.rex
)
