#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OOREXX_PREFIX=${OOREXX_PREFIX:-/usr/local}
REXX_BIN=${REXX_BIN:-$OOREXX_PREFIX/bin/rexx}
[[ -x "$REXX_BIN" ]] || { echo 'FAIL: exact ooRexx runtime required' >&2; exit 2; }
"$REXX_BIN" -v 2>&1 | grep -q 'Open Object Rexx Version 5.3.0 r13196' || { echo 'FAIL: exact ooRexx 5.3.0 r13196 required' >&2; exit 2; }
for c in openssl ffmpeg jq flock; do command -v "$c" >/dev/null || { echo "FAIL: $c required for H API qualification" >&2; exit 2; }; done

TMP=${H_API_TEST_ROOT:-$ROOT/tests/work-h-api}
PORT=${H_API_TEST_PORT:-19443}
rm -rf "$TMP" "$ROOT/input/ed209h/jobs/h-api-it-001" "$ROOT/results/ed209h/jobs/h-api-it-001"
mkdir -p "$TMP"/{certs,audio,spool,control,plans}
cleanup(){
  if [[ -n ${SERVER_PID:-} ]]; then kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; fi
  rm -rf "$ROOT/input/ed209h/jobs/h-api-it-001" "$ROOT/results/ed209h/jobs/h-api-it-001"
}
trap cleanup EXIT

# Local qualification CA and localhost server certificate.  Production H uses
# the operator-provisioned certificate; this fixture only proves the actual
# verified TLS API Client/HTTPS Server integration.
openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 1 \
  -subj '/CN=audio-h-test-ca' -keyout "$TMP/certs/ca.key" -out "$TMP/certs/ca.pem" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' \
  -keyout "$TMP/certs/server.key" -out "$TMP/certs/server.csr" >/dev/null 2>&1
cat > "$TMP/certs/server.ext" <<E
subjectAltName=DNS:localhost,IP:127.0.0.1
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
E
openssl x509 -req -sha256 -days 1 -in "$TMP/certs/server.csr" \
  -CA "$TMP/certs/ca.pem" -CAkey "$TMP/certs/ca.key" -CAcreateserial \
  -extfile "$TMP/certs/server.ext" -out "$TMP/certs/server.pem" >/dev/null 2>&1
printf '%s\n' 'h-api-integration-token-209' > "$TMP/control/token"
printf '%s\n' 'wrong-token-209' > "$TMP/control/bad-token"
chmod 600 "$TMP/control/token" "$TMP/control/bad-token" "$TMP/certs/server.key"

# 120-second raw fixtures permit 30-second windows at relative -30/0/+30
# around a base start of 60 without material crossing recording boundaries.
ffmpeg -nostdin -hide_banner -loglevel error -y \
  -f lavfi -i 'sine=frequency=500:sample_rate=16000:duration=120' \
  -f lavfi -i 'sine=frequency=2000:sample_rate=16000:duration=120' \
  -filter_complex '[0:a][1:a]amix=inputs=2:normalize=0' -ac 1 -c:a pcm_s16le "$TMP/audio/source.wav"
ffmpeg -nostdin -hide_banner -loglevel error -y \
  -f lavfi -i 'sine=frequency=500:sample_rate=16000:duration=120' \
  -ac 1 -c:a pcm_s16le "$TMP/audio/companion.wav"
printf '%s\n' NONE '450-550' > "$TMP/plans/bands.txt"

cat > "$TMP/job.txt" <<'J'
schema=audio.h.refinement.control/2
job_id=h-api-it-001
source_recording=source.wav
source_start_sec=60
companion_recording=companion.wav
companion_start_sec=60
companion_duration_sec=30
temporal_radius_sec=30
window_duration_sec=30
window_step_sec=30
window_overlap_sec=0
shortlist_count=2
workspace_budget_gib=1
parent.1.node=ed209c
parent.1.rank=1
parent.1.candidate_id=ed209c:C:test-parent
parent.1.score=4.0
parent.1.gain_db=24
parent.1.highpass_hz=50
parent.1.lowpass_hz=3000
parent.1.denoise_floor_db=NONE
parent.1.echo_delay_ms=0
parent.1.echo_gain=0
parent.1.cancel_strength=0
parent.1.cancel_tweak_ms=0
parent.1.compress=0
parent.1.compress_ratio=2
parent.1.compress_threshold_db=-18
parent.1.reject_bands=
parent.1.chain=gain=24dB -> hp=50Hz -> lp=3000Hz -> soft_limiter=.88/.98
parent_count=1
J
cat > "$TMP/observation.obs" <<'O'
schema=audio.pool.observation/1
message_id=ed209c-it-result-001
node_id=ed209c
kind=VOICE_DETECTED
thread_id=integration
in_reply_to=
candidate_id=ed209c:C:test-parent
score=4.0
summary=synthetic voice-frontier observation for HTTPS replay qualification
evidence_ref=tests/h-api
O
cp "$TMP/observation.obs" "$TMP/observation-conflict.obs"
sed -i 's/summary=synthetic voice-frontier observation for HTTPS replay qualification/summary=changed body under the same message id/' "$TMP/observation-conflict.obs"

"$ROOT/ensure_native_runtime.sh" >/dev/null
export OOREXX_PREFIX REXX_BIN
export REXX_PATH="$ROOT/lib:$ROOT/vendor/observation_v0.5:$ROOT/vendor/https_server_v0.4.4:$ROOT/vendor/api_client_v0.3:$ROOT/foreign:$OOREXX_PREFIX/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/foreign:$OOREXX_PREFIX/lib:$OOREXX_PREFIX/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export H_API_CERT_FILE="$TMP/certs/server.pem"
export H_API_KEY_FILE="$TMP/certs/server.key"
export H_API_TOKEN_FILE="$TMP/control/token"
export H_API_SPOOL_ROOT="$TMP/spool"
export H_AUDIO_ROOT="$TMP/audio"
export H_API_PORT="$PORT"
export H_API_BIND=127.0.0.1
export ED209H_API_URL="https://localhost:$PORT"
export ED209H_API_CA="$TMP/certs/ca.pem"
export ED209H_API_TOKEN_FILE="$TMP/control/token"
export AUDIO_SEARCH_FSYNC_HELPER="$ROOT/foreign/audio_checkpoint_fsync"

"$ROOT/h_api_server.sh" >"$TMP/server.log" 2>&1 & SERVER_PID=$!
ready=0
for _ in $(seq 1 30); do
  if "$ROOT/h_api.sh" health - >"$TMP/health.out" 2>&1; then ready=1; break; fi
  kill -0 "$SERVER_PID" 2>/dev/null || { cat "$TMP/server.log" >&2; echo 'FAIL: H API server exited during startup' >&2; exit 4; }
  sleep .2
done
(( ready == 1 )) || { cat "$TMP/server.log" >&2; echo 'FAIL: H API health never became ready' >&2; exit 4; }
grep -q '"ok":true' "$TMP/health.out" || { cat "$TMP/health.out"; echo 'FAIL: H health body' >&2; exit 4; }

# Authentication is ingress attribution/admission only.  This deliberately does
# not pretend that node_id in an Observation is cryptographic producer proof.
set +e
ED209H_API_TOKEN_FILE="$TMP/control/bad-token" "$ROOT/h_api.sh" health - >"$TMP/bad-auth.out" 2>&1
bad_rc=$?
set -e
(( bad_rc != 0 )) || { echo 'FAIL: bad H bearer token accepted' >&2; exit 5; }
grep -q 'UNAUTHORIZED' "$TMP/bad-auth.out" || { cat "$TMP/bad-auth.out"; echo 'FAIL: bad auth did not return UNAUTHORIZED' >&2; exit 5; }

"$ROOT/h_api.sh" observe "$TMP/observation.obs" >"$TMP/observe1.out"
"$ROOT/h_api.sh" observe "$TMP/observation.obs" >"$TMP/observe2.out"
grep -q '"idempotent":false' "$TMP/observe1.out"
grep -q '"idempotent":true' "$TMP/observe2.out"
set +e
"$ROOT/h_api.sh" observe "$TMP/observation-conflict.obs" >"$TMP/observe-conflict.out" 2>&1
obs_conflict_rc=$?
set -e
(( obs_conflict_rc != 0 )) || { echo 'FAIL: changed Observation body reused message id' >&2; exit 5; }
grep -q 'MESSAGE_ID_CONFLICT' "$TMP/observe-conflict.out"
"$ROOT/h_api.sh" replay 'ed209c:0:10' >"$TMP/replay.out"
grep -q 'VOICE_DETECTED' "$TMP/replay.out"
grep -q 'ed209c-it-result-001' "$TMP/replay.out"

# Prove the controller helper publishes both scalar RESULT evidence and the
# independent Pareto FRONTIER.  Neither publication is execution authority.
PUBDIR="$TMP/collected/ed209c"; mkdir -p "$PUBDIR"
cat > "$PUBDIR/candidate_configs.tsv" <<'C'
candidate_id	lane_id	rank	score	gain_db	highpass_hz	lowpass_hz	denoise_floor_db	echo_delay_ms	echo_gain	cancel_strength	cancel_tweak_ms	compress	compress_ratio	compress_threshold_db	reject_bands	chain
ed209c:C:front-a	ed209c:C	1	3.9	24	50	3000	NONE	0	0	0	0	0	2	-18		gain=24dB -> hp=50Hz -> lp=3000Hz
C
printf '%s\n' '{"schema":"audio.search.result/rexx-native-0.12-dev12","node":"ed209c"}' > "$PUBDIR/results.json"
cat > "$PUBDIR/pareto_candidates.tsv" <<'P'
candidate_id	lane_id	scalar_rank	scalar_score	pareto_rank	crowding_distance	reference_distance	pre_limiter_over_fraction	post_limiter_clip_fraction	material_ref	chain
ed209c:C:front-a	ed209c:C	1	3.9	1	1E99	3.9	0	0	rank_01.wav	chain-a
ed209c:C:front-b	ed209c:C	2	4.0	1	1E99	3.8	0.001	0	rank_02.wav	chain-b
P
AUDIO_POOL_OBSERVATION_DIR="$TMP/controller-observations" "$ROOT/publish_collected_observation.sh" ed209c "$PUBDIR" >"$TMP/publish-frontier.out"
"$ROOT/h_api.sh" replay 'ed209c:0:20' >"$TMP/replay-frontier.out"
grep -q 'FRONTIER' "$TMP/replay-frontier.out"
grep -q 'front-a' "$TMP/replay-frontier.out"
grep -q 'front-b' "$TMP/replay-frontier.out"

"$ROOT/h_api.sh" submit "$TMP/job.txt" >"$TMP/submit1.out"
"$ROOT/h_api.sh" submit "$TMP/job.txt" >"$TMP/submit2.out"
grep -q '"idempotent":false' "$TMP/submit1.out"
grep -q '"idempotent":true' "$TMP/submit2.out"
"$ROOT/h_api.sh" status h-api-it-001 >"$TMP/status-pending.out"
grep -q '"state":"PENDING"' "$TMP/status-pending.out"
cp "$TMP/job.txt" "$TMP/job-conflict.txt"
sed -i 's/shortlist_count=2/shortlist_count=1/' "$TMP/job-conflict.txt"
set +e
"$ROOT/h_api.sh" submit "$TMP/job-conflict.txt" >"$TMP/job-conflict.out" 2>&1
job_conflict_rc=$?
set -e
(( job_conflict_rc != 0 )) || { echo 'FAIL: changed H job reused job id' >&2; exit 5; }
grep -q 'JOB_ID_CONFLICT' "$TMP/job-conflict.out"

# Run the admitted job through H's real serial spool worker.  Override only the
# refinement catalogue for qualification speed; production H keeps its full
# conservative band plan catalogue.
H_BAND_PLAN_FILE="$TMP/plans/bands.txt" "$ROOT/h_api_worker.sh" --once >"$TMP/worker.out" 2>&1
"$ROOT/h_api.sh" status h-api-it-001 >"$TMP/status-complete.out"
grep -q '"state":"COMPLETE"' "$TMP/status-complete.out" || { cat "$TMP/worker.out"; cat "$TMP/status-complete.out"; exit 6; }
OUT="$ROOT/results/ed209h/jobs/h-api-it-001"
[[ -s "$OUT/H_TEMPORAL_SUMMARY.tsv" && -s "$OUT/H_BEST_WINDOWS.tsv" && -s "$OUT/review_candidates.tsv" && -s "$OUT/H_VOICE_MIX.tsv" && -s "$OUT/H_EVIDENCE.txt" ]] || { echo 'FAIL: H completed without refinement/mix evidence' >&2; exit 6; }
[[ $(($(wc -l < "$OUT/H_VOICE_MIX.tsv")-1)) -eq 3 ]] || { echo 'FAIL: H qualification did not emit one additive voice mix per parent/window pair' >&2; exit 6; }
grep -q '/h_voice_mix.wav' "$OUT/H_VOICE_MIX.tsv" || { echo 'FAIL: H aggregate voice-mix material reference missing' >&2; exit 6; }
grep -q '^additive_voice_mix_enabled=1$' "$OUT/H_EVIDENCE.txt" || { echo 'FAIL: H mix evidence disabled' >&2; exit 6; }
[[ $(($(wc -l < "$OUT/H_TEMPORAL_SUMMARY.tsv")-1)) -eq 3 ]] || { echo 'FAIL: H qualification did not process -30/0/+30 windows' >&2; exit 6; }
grep -q '^parent_window_cross_product=3$' "$OUT/H_EVIDENCE.txt"
grep -q '^window_overlap_sec=0$' "$OUT/H_EVIDENCE.txt"

# Observation durability is independent of the in-memory server object.  Restart
# the HTTPS process and prove replay is reconstructed from committed .obs files.
kill "$SERVER_PID"; wait "$SERVER_PID" 2>/dev/null || true; SERVER_PID=''
"$ROOT/h_api_server.sh" >"$TMP/server-restart.log" 2>&1 & SERVER_PID=$!
ready=0
for _ in $(seq 1 30); do
  if "$ROOT/h_api.sh" health - >/dev/null 2>&1; then ready=1; break; fi
  kill -0 "$SERVER_PID" 2>/dev/null || { cat "$TMP/server-restart.log" >&2; exit 7; }
  sleep .2
done
(( ready == 1 )) || { echo 'FAIL: H API restart health' >&2; exit 7; }
"$ROOT/h_api.sh" replay 'ed209c:0:10' >"$TMP/replay-after-restart.out"
grep -q 'ed209c-it-result-001' "$TMP/replay-after-restart.out" || { echo 'FAIL: Observation did not survive H restart' >&2; exit 7; }

printf 'PASS H API TLS/SPOOL/OBSERVATION/ROLLING/VOICE-MIX node=ed209h windows=3\n'
