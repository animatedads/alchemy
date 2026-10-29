#!/usr/bin/env bash
# No dev5 bundled deps, no database fixture, and no autobuilder required.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="$(cd "$here/../.." && pwd)"
mini="$repo/packages/notnotes_mini_approval_app_v0.1-dev16"
alchemy="$repo/packages/alchemy_notnotes_v0.1-dev15"
intent="$repo/packages/oorexx_intention_service"
mesh="$repo/packages/oorexx_instrumentation_mesh"
mesh_intent="$repo/packages/oorexx_instrumentation_intentions"

needed=(
  "$here/src/InitechHelpDesk.cls"
  "$here/tests/test_github_source_smoke.rex"
  "$mini/src/MiniNotesApp.cls"
  "$mini/src/MiniNotesInstrumentation.cls"
  "$mini/vendor/notnotes/AlchemyNotNotes.cls"
  "$mini/vendor/nosql/NoSQLServer.cls"
  "$alchemy/src/AlchemyNotNotesIntentions.cls"
  "$intent/src/IntentionService.cls"
  "$mesh/src/InstrumentationMesh.cls"
  "$mesh_intent/src/InstrumentationIntentions.cls"
)
for file in "${needed[@]}"; do
  [[ -f "$file" ]] || { printf 'FAIL missing required source: %s\n' "$file" >&2; exit 2; }
done
# Do not conflate the independent dev15 intentions class with Mini's dev14-patched vendor domain.
for known in \
  "11056f3b853e32b9efe5de11adea4902fb85b88775a75224ad864dea6ba97442 $alchemy/src/AlchemyNotNotesIntentions.cls" \
  "575c5ee7745c5fddb169a3b720488c08ec63a7b47878c1c31d37c12779083d14 $mini/src/MiniNotesApp.cls" \
  "92c56a66639625e30b714818fc59e4ad11ddb8ca73f7b9e9f392ac05fcc9f9e1 $mini/vendor/notnotes/AlchemyNotNotes.cls"; do
  sha="${known%% *}"; file="${known#* }"
  actual="$(sha256sum "$file")"; actual="${actual%% *}"
  [[ "$actual" == "$sha" ]] || { printf 'FAIL incompatible pinned source %s expected %s observed %s\n' "$file" "$sha" "$actual" >&2; exit 3; }
done

if [[ -n "${OOREXX_ROOT:-}" ]]; then
  rexx="$OOREXX_ROOT/usr/local/bin/rexx"
  rexxc="$OOREXX_ROOT/usr/local/bin/rexxc"
  export LD_LIBRARY_PATH="$OOREXX_ROOT/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export PATH="$OOREXX_ROOT/usr/local/bin:$PATH"
else
  rexx="${REXX:-$(command -v rexx || true)}"
  rexxc="${REXXC:-$(command -v rexxc || true)}"
fi
[[ -x "$rexx" && -x "$rexxc" ]] || { echo 'FAIL ooRexx interpreter/compiler unavailable' >&2; exit 4; }
export REXX_PATH="$here/src:$mini:$mini/src:$mini/vendor/notnotes:$mini/vendor/nosql:$mini/vendor/pdf/src:$mini/vendor/cliui/rexx:$mini/vendor/instrumentation:$mini/vendor/time/src:$mini/vendor/spreadsheet:$mini/vendor/connect:$alchemy/src:$intent/src:$intent/src/nlp:$mesh/src:$mesh_intent/src:${REXX_PATH:-}"

"$rexx" -v | head -3
"$rexxc" "$here/src/InitechHelpDesk.cls" >/dev/null
"$rexxc" "$here/src/InitechHelpDeskApiClientLLM.cls" >/dev/null
store="$(mktemp -d)"
trap 'rm -rf "$store"' EXIT
# Mini's relative ::requires are rooted at the application package, never at the caller's shell cwd.
cd "$mini"
TEST_DATA_ROOT="$store" "$rexx" "$here/tests/test_github_source_smoke.rex"
echo 'PASS Initech source-only repository smoke'