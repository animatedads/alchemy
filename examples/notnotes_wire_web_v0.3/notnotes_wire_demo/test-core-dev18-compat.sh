#!/usr/bin/env bash
# Consumer-owned cross-version probe. This does not migrate an existing store
# or modify any NotNotes core source. Both inputs are exact external artifacts.
set -euo pipefail

usage() {
  echo "usage: $0 /path/notnotes_wire_web_v0.3_20261111.zip /path/notnotes_mini_approval_app_v0.1-dev18 [--diagnostic-overlay]" >&2
  exit 2
}

[[ $# == 2 || $# == 3 ]] || usage
bundle=$1
core=$2
mode=${3:---raw}
[[ $mode == --raw || $mode == --diagnostic-overlay ]] || usage
[[ -f $bundle && -f $core/src/MiniNotesApp.cls && -f $core/src/MiniNotesPersistence.cls ]] || usage
for tool in sha256sum unzip patch node timeout; do
  command -v "$tool" >/dev/null || { echo "MISSING_TOOL=$tool" >&2; exit 2; }
done

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
expected=0187ea35a47f8055bdf4ff046aeb5afce28b29ec620dec9fe0235a1794af66ed
actual=$(sha256sum "$bundle")
actual=${actual%% *}
if [[ $actual != "$expected" ]]; then
  echo "REFUSED: ZIP_SHA256_MISMATCH actual=$actual expected=$expected" >&2
  exit 2
fi

temp=$(mktemp -d "${TMPDIR:-/tmp}/notnotes-core-compat-XXXXXXXX")
cleanup() { if [[ -n ${temp:-} && -d $temp ]]; then rm -r -- "$temp"; fi; }
trap cleanup EXIT
unzip -q "$bundle" -d "$temp"
stage=$temp/notnotes_wire_web_v0.3
[[ -d $stage/src && -x $stage/notnotes_wire_demo/test-demo.sh ]] || {
  echo "REFUSED: BAD_BUNDLE_LAYOUT" >&2; exit 2;
}

# Overlay exactly the published dev18 application sources in the disposable
# test tree; retain v0.3's pinned runtime and peer dependencies unchanged.
for name in MiniNotesApp MiniNotesPersistence MiniNotesRexxSqlEngine MiniNotesTime MiniNotesInstrumentation; do
  cp -- "$core/src/$name.cls" "$stage/src/$name.cls"
done
for name in vendor/connect/ConnectSelector.cls vendor/time/src/SingleTime.cls vendor/time/src/TzifZoneProvider.cls; do
  [[ -f $core/$name ]] || { echo "REFUSED: CORE_DEPENDENCY_ABSENT $name" >&2; exit 2; }
  mkdir -p -- "$stage/$(dirname "$name")"
  cp -- "$core/$name" "$stage/$name"
done
cp -- "$here/compat-backend-probe.rex" "$stage/notnotes_wire_demo/compat-backend-probe.rex"
echo "CORE_APP_SHA256=$(sha256sum "$core/src/MiniNotesApp.cls" | cut -d' ' -f1)"
echo "CORE_PERSISTENCE_SHA256=$(sha256sum "$core/src/MiniNotesPersistence.cls" | cut -d' ' -f1)"
echo "MODE=$mode"

if [[ $mode == --diagnostic-overlay ]]; then
  # Never apply this to the real Git tree or claim an unmodified dev18 PASS.
  patch --batch --forward --directory "$stage" -p1 < "$here/diagnostic-dev18-syntax.patch"
  echo "TEST_ONLY_SOURCE_WORKAROUNDS=4"
fi

# Explicit legacy file selection prevents silent data conversion. Tests create
# their own fresh temporary database and qualify the real Wire/Queue journey.
if (cd "$stage" && MININOTES_DB_BACKEND=file bash notnotes_wire_demo/test-demo.sh) > "$temp/file-mode.log" 2>&1; then
  tail -n 8 "$temp/file-mode.log"
  echo "NATIVE_FILE_BACKEND_WIRE=PASS"
else
  tail -n 24 "$temp/file-mode.log" >&2
  echo "NATIVE_FILE_BACKEND_WIRE=FAIL" >&2
  exit 1
fi

# Separate fail-closed probe: this environment may not have Rexx/SQL's shared
# indexed provider. A refused startup must never create a Wire access point.
(
  cd "$stage"
  source notnotes_wire_demo/env.sh
  timeout 20s env MININOTES_DB_BACKEND=rexxsql-sqlite "$OOREXX_HOME/bin/rexx" \
    notnotes_wire_demo/compat-backend-probe.rex "$temp/sqlite-new-store"
) > "$temp/sqlite.log" 2>&1 && sql_rc=0 || sql_rc=$?
if [[ $sql_rc == 0 ]]; then
  echo "SQL_SELECTOR_PRESENT=YES; actual SQLite transaction/restart qualification still required"
elif grep -q 'Could not find file "DatabaseBackendSelector.cls"' "$temp/sqlite.log"; then
  echo "SQL_PROVIDER_ABSENT_FAIL_CLOSED=PASS"
else
  tail -n 12 "$temp/sqlite.log" >&2
  echo "SQL_PROVIDER_FAILURE_UNCLASSIFIED=$sql_rc" >&2
  exit 1
fi
if [[ $mode == --diagnostic-overlay ]]; then
  echo "CORE_COMPAT=PASS_TEST_ONLY_OVERLAY_NOT_RELEASE"
else
  echo "CORE_COMPAT=PASS_EXACT_SOURCE_FILE_MODE_SQL_UNQUALIFIED"
fi
