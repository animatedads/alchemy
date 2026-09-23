#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
command -v ffmpeg >/dev/null 2>&1 || { echo 'FAIL: ffmpeg required' >&2; exit 2; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/campaign_audio" "$tmp/sample" "$tmp/alignment_reference" "$tmp/reference/prepared" "$tmp/exclusions" "$tmp/run"
cp "$ROOT/verify_prepared_samples.sh" "$tmp/"
mk() { ffmpeg -nostdin -hide_banner -loglevel error -y -f lavfi -i "anullsrc=r=16000:cl=mono" -t "$2" -c:a pcm_s16le "$1"; }
mkref() { ffmpeg -nostdin -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=$3:sample_rate=16000:duration=$2" -af volume=0.05 -ac 1 -c:a pcm_s16le "$1"; }
mk "$tmp/campaign_audio/campaign0945_source_094030_094930.wav" 540
mk "$tmp/campaign_audio/campaign0945_companion_094015_094945.wav" 570
mk "$tmp/sample/campaign0945_source_094330_094630.wav" 180
mk "$tmp/alignment_reference/campaign0945_companion_094315_094645.wav" 210
mkref "$tmp/reference/prepared/quality_target_01_whatsapp_16k_mono_pcm16.wav" 46.5 330
mkref "$tmp/reference/prepared/quality_target_02_upspeak_16k_mono_pcm16.wav" 56.81925 550
mkref "$tmp/reference/prepared/quality_target_03_quiet_voice_16k_mono_pcm16.wav" 48 770
mkref "$tmp/reference/prepared/quality_target_04_high_register_16k_mono_pcm16.wav" 48 990
cat > "$tmp/reference/QUALITY_CORPUS.tsv" <<'M'
# audio.quality.corpus/2
# path	id	coverage
prepared/quality_target_01_whatsapp_16k_mono_pcm16.wav	q1	test
prepared/quality_target_02_upspeak_16k_mono_pcm16.wav	q2	test
prepared/quality_target_03_quiet_voice_16k_mono_pcm16.wav	q3	test
prepared/quality_target_04_high_register_16k_mono_pcm16.wav	q4	test
M
cat > "$tmp/exclusions/campaign0945_cctv_alarm_source_master.tsv" <<'M'
# schema=cctv.alarm.exclusion/1
# detector=test
start_sec	end_sec	reason	provenance	hot_frames	peak_dbfs_max	rms_dbfs_max
200.000000	202.000000	cctv_alarm	test	8	-0.01	-0.02
M
cat > "$tmp/exclusions/campaign0945_parent_source.tsv" <<'M'
start_sec	end_sec	reason	provenance	hot_frames	peak_dbfs_max	rms_dbfs_max
20	22	cctv_alarm	test	8	-0.01	-0.02
M
cat > "$tmp/exclusions/campaign0945_parent_companion.tsv" <<'M'
start_sec	end_sec	reason	provenance	hot_frames	peak_dbfs_max	rms_dbfs_max
35	37	cctv_alarm	test	8	-0.01	-0.02
M
(cd "$tmp" && sha256sum \
  campaign_audio/campaign0945_source_094030_094930.wav \
  campaign_audio/campaign0945_companion_094015_094945.wav \
  sample/campaign0945_source_094330_094630.wav \
  alignment_reference/campaign0945_companion_094315_094645.wav \
  reference/prepared/*.wav \
  exclusions/campaign0945_cctv_alarm_source_master.tsv \
  exclusions/campaign0945_parent_source.tsv \
  exclusions/campaign0945_parent_companion.tsv > SAMPLES.sha256)
"$tmp/verify_prepared_samples.sh" | grep -q 'PASS verified prepared 09:45 campaign'

# Re-seal a corpus with byte-identical prepared references; semantic corpus
# verification must reject duplicate weighting even though hashes are current.
cp "$tmp/reference/prepared/quality_target_03_quiet_voice_16k_mono_pcm16.wav" "$tmp/reference/prepared/quality_target_04_high_register_16k_mono_pcm16.wav"
(cd "$tmp" && sha256sum \
  campaign_audio/campaign0945_source_094030_094930.wav \
  campaign_audio/campaign0945_companion_094015_094945.wav \
  sample/campaign0945_source_094330_094630.wav \
  alignment_reference/campaign0945_companion_094315_094645.wav \
  reference/prepared/*.wav \
  exclusions/campaign0945_cctv_alarm_source_master.tsv \
  exclusions/campaign0945_parent_source.tsv \
  exclusions/campaign0945_parent_companion.tsv > SAMPLES.sha256)
if "$tmp/verify_prepared_samples.sh" >/dev/null 2>&1; then
  echo 'FAIL: duplicate prepared quality references were accepted' >&2; exit 7
fi
mkref "$tmp/reference/prepared/quality_target_04_high_register_16k_mono_pcm16.wav" 48 990

# Required campaign alarm must fail closed when the detector produced no rows.
cat > "$tmp/exclusions/campaign0945_cctv_alarm_source_master.tsv" <<'M'
# schema=cctv.alarm.exclusion/1
# detector=test
start_sec	end_sec	reason	provenance	hot_frames	peak_dbfs_max	rms_dbfs_max
M
: > "$tmp/exclusions/campaign0945_parent_source.tsv"
: > "$tmp/exclusions/campaign0945_parent_companion.tsv"
# Re-seal so this test reaches the semantic zero-match guard rather than hash guard.
(cd "$tmp" && sha256sum \
  campaign_audio/campaign0945_source_094030_094930.wav \
  campaign_audio/campaign0945_companion_094015_094945.wav \
  sample/campaign0945_source_094330_094630.wav \
  alignment_reference/campaign0945_companion_094315_094645.wav \
  reference/prepared/*.wav \
  exclusions/campaign0945_cctv_alarm_source_master.tsv \
  exclusions/campaign0945_parent_source.tsv \
  exclusions/campaign0945_parent_companion.tsv > SAMPLES.sha256)
if "$tmp/verify_prepared_samples.sh" >/dev/null 2>&1; then
  echo 'FAIL: zero-alarm prepared fixture was accepted' >&2; exit 7
fi

# Restore a valid sealed fixture, then mutate one prepared byte: deploy verifier
# must reject it before any node contact.
cat > "$tmp/exclusions/campaign0945_cctv_alarm_source_master.tsv" <<'M'
# schema=cctv.alarm.exclusion/1
# detector=test
start_sec	end_sec	reason	provenance	hot_frames	peak_dbfs_max	rms_dbfs_max
200.000000	202.000000	cctv_alarm	test	8	-0.01	-0.02
M
cat > "$tmp/exclusions/campaign0945_parent_source.tsv" <<'M'
start_sec	end_sec	reason	provenance	hot_frames	peak_dbfs_max	rms_dbfs_max
20	22	cctv_alarm	test	8	-0.01	-0.02
M
cat > "$tmp/exclusions/campaign0945_parent_companion.tsv" <<'M'
start_sec	end_sec	reason	provenance	hot_frames	peak_dbfs_max	rms_dbfs_max
35	37	cctv_alarm	test	8	-0.01	-0.02
M
(cd "$tmp" && sha256sum \
  campaign_audio/campaign0945_source_094030_094930.wav \
  campaign_audio/campaign0945_companion_094015_094945.wav \
  sample/campaign0945_source_094330_094630.wav \
  alignment_reference/campaign0945_companion_094315_094645.wav \
  reference/prepared/*.wav \
  exclusions/campaign0945_cctv_alarm_source_master.tsv \
  exclusions/campaign0945_parent_source.tsv \
  exclusions/campaign0945_parent_companion.tsv > SAMPLES.sha256)
printf x >> "$tmp/exclusions/campaign0945_parent_source.tsv"
if "$tmp/verify_prepared_samples.sh" >/dev/null 2>&1; then
  echo 'FAIL: post-seal prepared-fixture tamper was accepted' >&2; exit 7
fi

echo 'PASS prepared-fixture fail-closed hash/alarm/projection verifier regression'
