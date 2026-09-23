#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for f in "$ROOT"/*.sh "$ROOT"/tests/*.sh; do bash -n "$f"; done
for f in "$ROOT"/jobs/ed209{a,b,c,d,e,i}.conf; do
  grep -qx 'source_recording=campaign0945_source_094030_094930.wav' "$f"
  grep -qx 'source_start_sec=180' "$f"
  grep -qx 'source_duration_sec=180' "$f"
  grep -qx 'source_wallclock=2023-10-10 09:43:30..09:46:30' "$f"
  grep -qx 'companion_recording=campaign0945_companion_094015_094945.wav' "$f"
  grep -qx 'companion_start_sec=180' "$f"
  grep -qx 'companion_duration_sec=210' "$f"
  grep -qx 'quality_target_set=AUDIO-QUALITY-TARGETS-V2' "$f"
done
[[ "$(for o in -180 -90 0 90 180; do echo -n "$((180+o)) "; done)" == '0 90 180 270 360 ' ]]
# Primary tp00006: 09:39:12 -> 09:45:00 = 348 s.
(( 348 - 270 == 78 )); (( 78 + 540 == 618 )); (( 78 + 180 == 258 )); (( 258 + 180 == 438 ))
# Companion master 09:40:15..09:49:45.
# tp00023 starts 09:09:27: 1848 s to 09:40:15 and 306 s to seam 09:45:21.
(( 1848 + 306 == 2154 )); (( 306 + 264 == 570 ))
# Parent alignment view begins 180 s into companion master and is 210 s long.
(( 180 + 210 == 390 ))
grep -q 'TP00006_SOURCE' "$ROOT/prepare_samples.sh"
grep -q 'TP00023_SOURCE' "$ROOT/prepare_samples.sh"
grep -q 'TP00024_SOURCE' "$ROOT/prepare_samples.sh"
grep -q 'AUDIO-QUALITY-TARGETS-V2' "$ROOT/reference/QUALITY_TARGETS.json"
for f in "$ROOT"/jobs/ed209{a,b,c,d,e,i}.conf; do grep -qx 'exclusion_policy=CCTV-ALARM-EXCLUSION-V1' "$f"; done
grep -Fq 'atrim=end_sample=8640000' "$ROOT/prepare_samples.sh"
grep -Fq 'detect_cctv_alarm.sh' "$ROOT/prepare_samples.sh"
grep -Fq 'apply_cctv_exclusions.sh' "$ROOT/prepare_samples.sh"
[[ $(sha256sum "$ROOT/reference/prepared/quality_target_01_whatsapp_16k_mono_pcm16.wav" | awk '{print $1}') == 60cd59d1256db067de6042b6c3fdb4e69525fd2c95c0412697e35bf37aa00e0f ]]
[[ $(sha256sum "$ROOT/reference/prepared/quality_target_02_upspeak_16k_mono_pcm16.wav" | awk '{print $1}') == 2b4d5583ce8e1179e69451ae3321e65e42933dab6c68504f6b98fa06d0c1f3ce ]]
[[ $(sha256sum "$ROOT/reference/prepared/quality_target_03_quiet_voice_16k_mono_pcm16.wav" | awk '{print $1}') == 7961f844949ec99298c7528fb4b349ae788cfed7175ac9355b3a4bd2c5f903b4 ]]
[[ $(sha256sum "$ROOT/reference/prepared/quality_target_04_high_register_16k_mono_pcm16.wav" | awk '{print $1}') == d5477826055e0f30918a6f28642dddfb9c830418fc4940138c9b186fc6b9b70d ]]
grep -qx '# audio.quality.corpus/2' "$ROOT/reference/QUALITY_CORPUS.tsv"
[[ $(awk '!/^#/ && NF{n++} END{print n+0}' "$ROOT/reference/QUALITY_CORPUS.tsv") -eq 4 ]]
! grep -qs 'evt_000071_16k_mono\|evt_000597_16k_mono' "$ROOT/node_worker.sh" "$ROOT/h_refinement_worker.sh" "$ROOT/refine_top.sh" "$ROOT/tests/run_local.sh"
echo 'PASS 09:45 arithmetic/camera-role/quality-target/H-window contract'
# Exact-sample companion authority: 570 s * 16 kHz = 9,120,000 samples.
grep -Fq 'atrim=end_sample=9120000' "$ROOT/prepare_samples.sh"
# Managed SSH config must be available to H staging.
grep -Fq 'ED209H_SSH_CONFIG' "$ROOT/stage_h_campaign_audio.sh"
# Regression: empty reject_bands TSV field must not collapse into processing chain.
tmpd=$(mktemp -d)
trap 'rm -rf "$tmpd"' EXIT
mkdir -p "$tmpd/collected/ed209a" "$tmpd/run"
printf 'x' > "$tmpd/collected/ed209a/rank_01.wav"
printf '%s\n' \
  $'candidate_id\tlane_id\trank\tscore\tgain_db\thighpass_hz\tlowpass_hz\tdenoise_floor_db\techo_delay_ms\techo_gain\tcancel_strength\tcancel_tweak_ms\tcompress\tcompress_ratio\tcompress_threshold_db\treject_bands\tchain' \
  $'A0001\tA\t1\t1.23\t18\t40\t3200\t\t0\t0\t0\t0\t0\t1\t-18\t\tgain=18dB -> hp=40Hz -> lp=3200Hz -> soft_limiter=.88/.98' \
  > "$tmpd/collected/ed209a/candidate_configs.tsv"
H_BASE_JOB="$ROOT/jobs/ed209a.conf" H_JOB_ID=test-empty-tsv \
  "$ROOT/prepare_h_api_job.sh" "$tmpd/collected" rank_01.wav "$tmpd/run/job.txt" >/dev/null
grep -qx 'parent.1.reject_bands=' "$tmpd/run/job.txt"
grep -qx 'parent.1.chain=gain=18dB -> hp=40Hz -> lp=3200Hz -> soft_limiter=.88/.98' "$tmpd/run/job.txt"
echo 'PASS H empty-TSV/exact-sample/staging hotfix regression'
# CCTV alarm exclusion regression: the detector runs on unamplified PCM, finds a
# repeated near-full-scale burst, and the masker preserves exact duration while
# removing that obvious high-level interval from the processing material.
alarm="$tmpd/alarm.wav"; alarm_mask="$tmpd/alarm.tsv"; alarm_masked="$tmpd/alarm-masked.wav"
ffmpeg -nostdin -hide_banner -loglevel error -y \
  -f lavfi -i 'anoisesrc=color=pink:sample_rate=16000:duration=12:amplitude=0.002' \
  -f lavfi -i 'sine=frequency=1200:sample_rate=16000:duration=2' \
  -filter_complex "[1:a]volume=20,alimiter=limit=0.999,adelay=4000|4000[alarm];[0:a][alarm]amix=inputs=2:duration=first:weights='1 1':normalize=0" \
  -c:a pcm_s16le "$alarm"
"$ROOT/detect_cctv_alarm.sh" "$alarm" "$alarm_mask" >/dev/null
alarm_n=$(awk -F '\t' '!/^#/ && $1!="start_sec" {n++} END{print n+0}' "$alarm_mask")
(( alarm_n >= 1 ))
awk -F '\t' '!/^#/ && $1!="start_sec" {if($1<4.5 && $2>5.5) ok=1} END{exit(ok?0:1)}' "$alarm_mask"
"$ROOT/apply_cctv_exclusions.sh" "$alarm" "$alarm_mask" "$alarm_masked" 0
[[ $(ffprobe -v error -select_streams a:0 -show_entries stream=duration_ts -of default=nw=1:nk=1 "$alarm") == \
   $(ffprobe -v error -select_streams a:0 -show_entries stream=duration_ts -of default=nw=1:nk=1 "$alarm_masked") ]]
# The excluded centre must now be essentially digital silence.
masked_rms=$(ffmpeg -nostdin -hide_banner -loglevel info -ss 4.5 -t 1 -i "$alarm_masked" -af astats=metadata=0:reset=0 -f null - 2>&1 | awk -F ': ' '/Overall/{o=1} o && /RMS level dB/ {print $2; exit}')
if [[ "$masked_rms" != '-inf' ]]; then awk -v r="${masked_rms:--200}" 'BEGIN{exit((r+0)<-90?0:1)}'; fi
echo 'PASS CCTV-ALARM-EXCLUSION-V1 detector/mask/timeline regression'

# Column-count guard: malformed candidate TSV must fail before field parsing.
printf '%s\n' $'A0002\tA\t1\t1.23\t18\t40' > "$tmpd/collected/ed209a/candidate_configs.tsv"
if H_BASE_JOB="$ROOT/jobs/ed209a.conf" H_JOB_ID=test-bad-tsv \
     "$ROOT/prepare_h_api_job.sh" "$tmpd/collected" rank_01.wav "$tmpd/run/bad-job.txt" >/dev/null 2>&1; then
  echo 'FAIL: malformed candidate TSV was accepted' >&2; exit 7
fi
echo 'PASS H TSV expected-column-count fail-closed regression'
# dev11 production-boundary invariants: a sealed prepared fixture is verified
# before deployment and the known 09:45 CCTV alarm may not silently disappear.
grep -Fq '"$ROOT/verify_prepared_samples.sh"' "$ROOT/deploy_all.sh"
grep -Fq '"$ROOT/verify_prepared_samples.sh"' "$ROOT/prepare_samples.sh"
grep -Fq 'CCTV_ALARM_REQUIRE_MATCH' "$ROOT/verify_prepared_samples.sh"
"$ROOT/tests/test_prepared_verifier.sh"
