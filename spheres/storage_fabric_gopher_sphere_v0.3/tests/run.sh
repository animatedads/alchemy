#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to the qualified LLM Gopher executable}"
T="${TMPDIR:-/tmp}/storage-fabric-sphere.$$"
trap 'rm -rf "$T"' EXIT HUP INT TERM
mkdir -p "$T"

"$GOPHER" --profile storage-fabric context storage-fabric --full > "$T/context.json"
grep -q 'arch.storage-fabric.ownership' "$T/context.json"
grep -q 'arch.storage-fabric.lifecycle-safety' "$T/context.json"
grep -q 'arch.storage-fabric.locality-placement' "$T/context.json"
grep -q 'arch.storage-fabric.transfer' "$T/context.json"
grep -q 'arch.storage-fabric.provider-capability-security' "$T/context.json"
grep -q 'arch.storage-fabric.node-inventory' "$T/context.json"

for q in 'TVFS' 'disposable' 'capacity domain' 'job to data' 'Google Drive' 'verification' 'partial' 'capability' 'inventory' 'ed209' 'fdisk' 'unknown-capacity'; do
  "$GOPHER" --profile storage-fabric search "$q" --sphere storage-fabric > "$T/search.json"
  grep -q '"class": "FOUND"' "$T/search.json"
done

"$GOPHER" --profile storage-fabric search locality --sphere storage-fabric --corpus storage-fabric.lessons > "$T/locality.json"
grep -q 'moving the job to data' "$T/locality.json"

"$GOPHER" --profile storage-fabric search StorageRef --sphere storage-fabric --corpus storage-fabric.glossary > "$T/glossary.json"
grep -q 'Stable logical identity' "$T/glossary.json"

"$GOPHER" --profile storage-fabric open arch.storage-fabric.lifecycle-safety > "$T/safety.json"
grep -q 'verified disposable copy does not authorize eviction' "$T/safety.json"

"$GOPHER" --profile storage-fabric open arch.storage-fabric.node-inventory > "$T/node.json"
grep -q 'UNQUALIFIED' "$T/node.json"
grep -q 'Job-to-Node' "$T/node.json"

"$GOPHER" --profile storage-fabric search device-admission --sphere storage-fabric --corpus storage-fabric.lessons > "$T/device.json"
grep -q 'not allocatable storage until explicitly admitted' "$T/device.json"

echo 'PASS STORAGE FABRIC SPHERE v0.3'
