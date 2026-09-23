#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mkdir -p "$ROOT/run/test"
rm -rf "$ROOT/run/test/coordinator_workers"
for w in ed209a ed209b ed209c ed209d ed209e ed209h ed209i; do mkdir -p "$ROOT/run/test/coordinator_workers/$w/evidence"; done
"$ROOT/native/build_native.sh" >/dev/null
"$ROOT/native/build_fixture.sh" >/dev/null
"$ROOT/tools/prepare_runtime.sh" >/dev/null
"$ROOT/tests/test_corpus_authority.sh"
"$ROOT/tests/test_decode_geometry.sh"
"$ROOT/native/make_spatial_fixture" "$ROOT/run/test/a120.f32" "$ROOT/run/test/b120.f32" 8000 12 960
"$ROOT/native/make_loud_echo_fixture" "$ROOT/run/test/loud_fc.f32" "$ROOT/run/test/loud_fd.f32"
for f in "$ROOT"/src/*.cls "$ROOT"/tools/*.rex "$ROOT"/tests/*.rex; do "$ROOT/tools/run_rexxc_pinned.sh" "$f" >/dev/null; done
do_test() { echo "TEST $(basename "$1")"; "$ROOT/tools/run_rexx_pinned.sh" "$1"; }
do_test "$ROOT/tests/test_campaign_contract.rex"
do_test "$ROOT/tests/test_spatial_evidence.rex"
do_test "$ROOT/tests/test_spatial_native_provider.rex"
do_test "$ROOT/tests/test_loud_echo_scan.rex"
do_test "$ROOT/tests/test_loud_echo_scan_v2.rex"
do_test "$ROOT/tests/test_loud_echo_scan_v3.rex"
do_test "$ROOT/tests/test_search_landmark.rex"
do_test "$ROOT/tests/test_search_landmark_summary.rex"
do_test "$ROOT/tests/test_reflection_aware_reconstruction.rex"
"$ROOT/tests/test_vehicle_reflection_correlation.sh"
do_test "$ROOT/tests/test_acoustic_character.rex"
do_test "$ROOT/tests/test_soft_reconstruction.rex"
do_test "$ROOT/tests/test_acoustic_coordinator.rex"
do_test "$ROOT/tests/test_calibration_bounded_acoustic.rex"
do_test "$ROOT/tests/test_tsv_csvstream.rex"
"$ROOT/tests/test_calibration_runtime_bounds.sh"
"$ROOT/tests/test_calibration_16s_pipeline.sh"
do_test "$ROOT/tests/test_spatial_coordinator.rex"
do_test "$ROOT/tests/test_file_edge_alignment.rex"
do_test "$ROOT/tests/test_file_edge_calibration_v2.rex"
"$ROOT/tests/test_file_edge_calibration_pipeline_v2.sh"
"$ROOT/tests/test_edge_calibration_plan.sh"
"$ROOT/tests/test_legacy_edge_map_refusal.sh"
"$ROOT/tests/test_source_selection_native.sh"
"$ROOT/tests/test_source_calibration_masks.sh"
"$ROOT/tests/test_source_conditioned_paths.sh"
"$ROOT/tests/test_source_conditioned_job_plan.sh"
"$ROOT/tests/test_source_conditioned_worker_merge.sh"
"$ROOT/tests/test_source_conditioned_complexity_continue.sh"
do_test "$ROOT/tests/test_tf_mask_policy.rex"
"$ROOT/tests/test_tf_mask_audio.sh"
do_test "$ROOT/tests/test_evidence_graph.rex"
do_test "$ROOT/tests/test_graph_wobble.rex"
do_test "$ROOT/tests/test_quality_graph_archive.rex"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tests/test_quality_graph_renderer.rex" "$ROOT/run/test/quality_graphs.tsv" "$ROOT/run/test/quality_graph_render"
"$ROOT/tests/test_quality_graph_pipeline.sh"
for f in "$ROOT"/tools/*.sh "$ROOT"/native/*.sh "$ROOT"/tests/*.sh; do sh -n "$f"; done
"$ROOT/tools/discover_worker.sh" >/dev/null
"$ROOT/tests/test_reconstruction_processing.sh"
echo 'PASS audio_v9_voice_recovery_v0.1-dev16'
