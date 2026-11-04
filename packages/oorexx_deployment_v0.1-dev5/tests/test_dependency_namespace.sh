#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/deployment-ns-test.XXXXXX")
trap 'rm -rf "$w"' EXIT HUP INT TERM
mkdir -p "$w/consumer/src" "$w/provider/lib"
printf '%s\n' "say 'entry'" > "$w/consumer/src/main.rex"
printf '%s\n' "::class Helper public" > "$w/provider/lib/Helper.cls"
consumer_hash=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
provider_hash=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
TAB=$(printf '\t')
cat > "$w/lock.tsv" <<EOF2
authority${TAB}SSC_SEALED_DEPLOYMENT/1
artifact${TAB}Consumer${TAB}MAIN${TAB}7${TAB}dep-consumer-7${TAB}${consumer_hash}
artifact${TAB}Provider${TAB}MAIN${TAB}12${TAB}dep-provider-12${TAB}${provider_hash}
package${TAB}Consumer${TAB}src/main.rex${TAB}Helper.cls${TAB}Provider${TAB}lib/Helper.cls${TAB}1${TAB}sealed exact dependency
EOF2
cat > "$w/roots.tsv" <<EOF2
Consumer${TAB}$w/consumer${TAB}${consumer_hash}
Provider${TAB}$w/provider${TAB}${provider_hash}
EOF2
"$ROOT/bin/materialize_dependency_namespace.sh" --lock "$w/lock.tsv" --roots "$w/roots.tsv" --output "$w/ns" --entry Consumer:src/main.rex
"$ROOT/bin/verify_dependency_namespace.sh" "$w/ns"
[ -f "$w/ns/components/Consumer-$(printf Consumer | sha256sum | cut -c1-12)/src/main.rex" ]
[ -f "$w/ns/components/Provider-$(printf Provider | sha256sum | cut -c1-12)/lib/Helper.cls" ]
! grep -F '/ambient/' "$w/ns/evidence/rexx-path.txt" >/dev/null 2>&1
# Root substitution must fail closed.
sed "s/${provider_hash}/cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc/" "$w/roots.tsv" > "$w/bad-roots.tsv"
if "$ROOT/bin/materialize_dependency_namespace.sh" --lock "$w/lock.tsv" --roots "$w/bad-roots.tsv" --output "$w/bad" --entry Consumer:src/main.rex >/dev/null 2>&1; then
  echo 'FAIL mismatched provider authority was accepted' >&2
  exit 1
fi
# An unsatisfied lock must fail before output mutation.
sed "s/${TAB}1${TAB}sealed/${TAB}0${TAB}sealed/" "$w/lock.tsv" > "$w/bad-lock.tsv"
if "$ROOT/bin/materialize_dependency_namespace.sh" --lock "$w/bad-lock.tsv" --roots "$w/roots.tsv" --output "$w/bad2" --entry Consumer:src/main.rex >/dev/null 2>&1; then
  echo 'FAIL unsatisfied lock was accepted' >&2
  exit 1
fi
echo 'PASS deterministic dependency namespace'
