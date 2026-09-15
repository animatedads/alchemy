#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-3498}"
OOREXX_ROOT="${OOREXX_ROOT:-}"
if [[ -n "$OOREXX_ROOT" ]]; then
  export PATH="$OOREXX_ROOT/bin:$PATH"
  export LD_LIBRARY_PATH="$OOREXX_ROOT/lib:${LD_LIBRARY_PATH:-}"
fi
command -v rexx >/dev/null || { echo 'ooRexx rexx executable not found; set OOREXX_ROOT or PATH' >&2; exit 2; }
command -v unzip >/dev/null || { echo 'unzip required' >&2; exit 2; }
WORK="$(mktemp -d /tmp/frankenstack_v10.XXXXXX)"
PID=""
cleanup(){ if [[ -n "$PID" ]]; then kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; fi; rm -rf "$WORK"; }
trap cleanup EXIT
mkdir -p "$WORK/components"
for z in "$HERE"/vendor/*.zip; do
  name="$(basename "$z" .zip)"; mkdir -p "$WORK/components/$name"; unzip -q "$z" -d "$WORK/components/$name"
done
STRUCT_ROOT="$WORK/components/structured_relation_plugin_v0.9/structured_relation_plugin_v0.9"
REG_ROOT="$WORK/components/runtime_registry_v0.11/runtime_registry_v0.11"
LEGAL_ROOT="$WORK/components/legal_effect_v0.7/legal_effect_v0.7"
RYTA_ROOT="$WORK/components/virtual_ryta_hardworld_v0.19/virtual_ryta_hardworld_v0.19"
QUEUE_ROOT="$WORK/components/oorexx_queue_fabric_v0.8.1/oorexx_queue_fabric_v0.8.1"
NS_ROOT="$WORK/components/nosqlserver_v0.74/nosqlserver_v0.74"
MS_ROOT="$WORK/components/msqlshim_v0.12/msqlshim_v0.12"
DB_ROOT="$WORK/components/oorexx_db_skeleton_v0_39/oorexx_db_skeleton_v0_39"
for d in "$STRUCT_ROOT" "$REG_ROOT" "$LEGAL_ROOT" "$RYTA_ROOT" "$QUEUE_ROOT" "$NS_ROOT" "$MS_ROOT" "$DB_ROOT"; do [[ -d "$d" ]] || { echo "missing component root: $d" >&2; exit 2; }; done
(cd "$MS_ROOT" && ./bind_backend.sh "$NS_ROOT/src/NoSQLServer.cls" >/dev/null)

printf '%s\n' '=== Runtime ==='
rexx -v | head -n 4
export REXX_PATH="$NS_ROOT/src:$NS_ROOT/tests:$STRUCT_ROOT/src:$QUEUE_ROOT/src:$REG_ROOT/src:$LEGAL_ROOT/src:$RYTA_ROOT:$RYTA_ROOT/algorithm:$RYTA_ROOT/integration"
if [[ "${SKIP_PREFLIGHTS:-0}" == "1" ]]; then
  printf '\n%s\n' '=== Focused component preflights skipped for integration-only run ==='
else
  printf '\n%s\n' '=== Focused current-stack preflight ==='
  (cd "$NS_ROOT/tests" && rexx v072_general_join_on_smoke.rex)
  (cd "$STRUCT_ROOT/tests" && rexx ourladyair_nosql_seat_offer_smoke.rex)
  (cd "$QUEUE_ROOT/tests" && rexx test_queue_distributed_topics.rex && rexx test_queue_distributed_topic_recovery.rex)
  (cd "$REG_ROOT" && rexx tests/test_runtime_execution_evidence.rex "$REG_ROOT")
  (cd "$LEGAL_ROOT" && rexx tests/test_legal_effect_core.rex)
  (cd "$RYTA_ROOT/tests" && rexx test_table_feed_authority_matrix.rex)
  (cd "$DB_ROOT" && rexx compile_smoke.rex)
  echo 'FOCUSED CURRENT-STACK PREFLIGHT: OK'
fi

# Wire harness executes inside HardWorld/tests so its native relative requires
# resolve exactly as the component's own tests expect.
rm -rf "$RYTA_ROOT/tests/src" "$RYTA_ROOT/tests/vendor" "$RYTA_ROOT/tests/TribunalObjects.cls" "$RYTA_ROOT/tests/frankenstack_v10_wire.rex"
ln -s "$MS_ROOT/src" "$RYTA_ROOT/tests/src"
ln -s "$MS_ROOT/vendor" "$RYTA_ROOT/tests/vendor"
cp "$HERE/TribunalObjects.cls" "$RYTA_ROOT/tests/TribunalObjects.cls"
cp "$HERE/frankenstack_v10_wire.rex" "$RYTA_ROOT/tests/frankenstack_v10_wire.rex"
cp "$HERE/frankenstack_v10_database_facade.rex" "$DB_ROOT/frankenstack_v10_database_facade.rex"
DBDATA="$WORK/live_db"; QMA="$WORK/qm_a"; QMB="$WORK/qm_b"; mkdir -p "$DBDATA"
LOG="$WORK/wire.log"
(cd "$RYTA_ROOT/tests" && exec rexx frankenstack_v10_wire.rex "$DBDATA" "$PORT" 127.0.0.1 "$HERE/samples/ourladyair_pnrgov_demo.edi" "$HERE/SeatOfferCapability_v1.cls" "$HERE/SeatOfferCapability_v2.cls" "$QMA" "$QMB") >"$LOG" 2>&1 & PID=$!
python3 - "$PORT" "$LOG" <<'PY'
import socket,sys,time,os
port=int(sys.argv[1]); log=sys.argv[2]
for _ in range(600):
    if os.path.exists(log) and 'WIRE READY' in open(log,errors='replace').read():
        try:
            s=socket.create_connection(('127.0.0.1',port),timeout=.2); s.close(); break
        except OSError: pass
    time.sleep(.05)
else:
    print(open(log,errors='replace').read(),file=sys.stderr)
    raise SystemExit('wire server did not become ready')
PY
kill -0 "$PID" 2>/dev/null || { cat "$LOG" >&2; exit 1; }
MYSQL=("$HERE/mysqltoy" --batch --raw --host 127.0.0.1 --port "$PORT" --user tribunal nosqlserver)

printf '\n%s\n' '=== Native G07 PNRGOV evidence ==='
printf "SELECT evidence_id,group_ref,message_ref,surname,given_name,service_code,service_value,source_path,source_kind,source_identity_preserved FROM structured_offer_evidence ORDER BY message_ref;\n" | "${MYSQL[@]}"
printf '\n%s\n' '=== Runtime generation evidence: captured history vs current generation ==='
printf "SELECT phase,generation_id,version,artifact_id,generation_state,captured_state,locator FROM runtime_execution_evidence ORDER BY phase;\n" | "${MYSQL[@]}"
printf '\n%s\n' '=== Same sealed synthetic legal generation, different action time ==='
printf "SELECT phase,event_time,evaluation_time,assessment_status,dispositions,legal_generation_id,runtime_generation_id,note FROM legal_time_assessments ORDER BY phase;\n" | "${MYSQL[@]}"
printf '\n%s\n' '=== Retained authority time bomb ==='
printf "SELECT case_id,publication_id,publisher_remote_count,retained_at_a,consumer_depth,consumer_payload_class,publisher_legal_status,consumer_legal_status,receipt_count,duplicate_suppressed,provenance_preserved FROM retained_authority_case;\n" | "${MYSQL[@]}"
printf '\n%s\n' '=== Queue Fabric v0.8.1 durable retained state and receipt ==='
printf "SELECT publication_id,topic_name,topic_string,payload_class,correlation_id FROM mqa_retained_publications;\n" | "${MYSQL[@]}"
printf "SELECT publication_id,topic_name,topic_string,payload_class,correlation_id FROM mqb_retained_publications;\n" | "${MYSQL[@]}"
printf "SELECT receipt_id,origin_manager,publication_id,destination_topic,source_manager FROM mqb_topic_distribution_receipts;\n" | "${MYSQL[@]}"
printf '\n%s\n' '=== Explicit evidence -> authority promotion ==='
printf "SELECT promotion_id,evidence_type,evidence_key,promoted_meaning,authority_effect,provenance FROM retained_authority_promotions ORDER BY promotion_id;\n" | "${MYSQL[@]}"
printf '\n%s\n' '=== HardWorld: transport provenance is not current authority ==='
printf "SELECT row_id,preference_score,upstream_disposition,disposition,final_selected,reason FROM retained_authority_decisions ORDER BY row_id;\n" | "${MYSQL[@]}"
printf '\n%s\n' '=== Prepared cursor remains observational ==='
python3 "$HERE/prepared_cursor_client.py" "$PORT"
printf '\n%s\n' '=== Mutation attacks against evidence/transport/decision snapshots ==='
mutations=(
"UPDATE structured_offer_evidence SET service_code='SEAT' WHERE evidence_id='G07-G07A'"
"UPDATE mqb_retained_publications SET topic_name='APPROVED' WHERE topic_name='SEAT.OFFERS'"
"DELETE FROM mqb_topic_distribution_receipts WHERE origin_manager='QM.A'"
"INSERT INTO mqb_topic_distribution_receipts VALUES ('fake','QM.X','p','SEAT.OFFERS','QM.X','now')"
"UPDATE retained_authority_decisions SET disposition='PERMITTED' WHERE row_id='ACT_ON_RETAINED_OFFER'"
)
for mutation in "${mutations[@]}"; do
  set +e; OUT="$(printf '%s;\n' "$mutation" | "${MYSQL[@]}" 2>&1)"; RC=$?; set -e
  printf '%s\n%s\nrc=%s\n' "$mutation" "$OUT" "$RC"
  [[ "$RC" -ne 0 ]] || { echo "tamper unexpectedly succeeded: $mutation" >&2; exit 1; }
done
printf '\n%s\n' '=== Database Core v0.39 round-trip ==='
(cd "$DB_ROOT" && rexx frankenstack_v10_database_facade.rex 127.0.0.1 "$PORT" nosqlserver tribunal "$HERE/mysqltoy")
printf '\n%s\n' '=== Wire server / provider log ==='
cat "$LOG"
printf '\n%s\n' 'FRANKENSTACK V0.10 RETAINED AUTHORITY TIME BOMB: OK'
