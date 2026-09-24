#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MATHS_REXX="${MATHS_REXX:-}"
UNITS_REXX="${UNITS_REXX:-}"
if [[ -z "$MATHS_REXX" ]]; then
  echo "Set MATHS_REXX to the authoritative ooRexx Maths v0.8 rexx directory" >&2
  exit 2
fi
if [[ -z "$UNITS_REXX" ]]; then
  echo "Set UNITS_REXX to the authoritative ooRexx Units v0.1-dev4 rexx directory" >&2
  exit 2
fi
UNITS_ROOT="$(cd "$UNITS_REXX/.." && pwd)"
if [[ ! -f "$UNITS_ROOT/VERSION" ]] || [[ "$(tr -d '\r\n' < "$UNITS_ROOT/VERSION")" != "0.1-dev4" ]]; then
  echo "Physics v0.1-dev10 requires ooRexx Units v0.1-dev4" >&2
  exit 2
fi
export REXX_PATH="$ROOT/rexx:$UNITS_REXX:$MATHS_REXX${REXX_PATH:+:$REXX_PATH}"

# Unit authority is intentionally singular. Fail qualification if old Physics
# compatibility names are reintroduced into executable source, tests or examples.
if grep -RInE '\.(PhysicsDimension|PhysicsUnit|PhysicsQuantity)~|\.SI~|::class[[:space:]]+(PhysicsDimension|PhysicsUnit|PhysicsQuantity|SI)([[:space:]]|$)' \
    "$ROOT/rexx" "$ROOT/tests" "$ROOT/examples"; then
  echo "Legacy Physics unit compatibility facade detected" >&2
  exit 3
fi

for t in "$ROOT"/tests/*.rex; do
  echo "== $(basename "$t") =="
  rexx "$t"
done

if command -v rexxc >/dev/null 2>&1; then
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  for path in "$ROOT"/rexx/*.cls; do
    f="$(basename "$path")"
    echo "== rexxc $f =="
    rexxc "$path" "$tmpdir/${f%.cls}.orx"
  done
fi
