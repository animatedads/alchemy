#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
FILES=("$HERE/src/CivicNotamJournal.cls" "$HERE/src/CivicNotamRelation.cls" "$HERE/src/CivicNotamRuntime.cls")
if grep -Eiq 'JMSBSFProvider|SolJNDI|InitialContext|SecretLease|SecretBroker|createConsumer|createConnection|~claim\(|~ack\(|~nack\(|HardWorld|CivicPromotion' "${FILES[@]}"; then
  echo "FAIL v0.14 NOTAM evidence surfaces leaked transport/secret/promotion authority" >&2
  exit 1
fi
if grep -Eiq 'effective_start_datetime|effective_end_datetime|current_active|is_active|DateTime~from|YYMMDDHHMM.*convert' "${FILES[@]}"; then
  echo "FAIL v0.14 NOTAM evidence surfaces gained operational time inference" >&2
  exit 1
fi
echo "PASS test_notam_surface_boundary_v014"
