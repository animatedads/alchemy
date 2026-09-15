#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
ML_ROOT="${ML_ROOT:-}"
FOREIGN_ROOT="${FOREIGN_ROOT:-}"
export REXX_PATH="$ROOT/src${ML_ROOT:+:$ML_ROOT/src:$ML_ROOT/lib}${FOREIGN_ROOT:+:$FOREIGN_ROOT/rexx}${REXX_PATH:+:$REXX_PATH}"
if [[ -n "$FOREIGN_ROOT" ]]; then export LD_LIBRARY_PATH="$FOREIGN_ROOT/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi

"$REXX_BIN" "$ROOT/tests/test_graph_model.rex"
"$REXX_BIN" "$ROOT/tests/test_point_series.rex"
"$REXX_BIN" "$ROOT/tests/test_graph_views.rex"
"$REXX_BIN" "$ROOT/tests/test_svg_renderer.rex" "$ROOT/qualification/test_mlgraph.svg"
"$REXX_BIN" "$ROOT/tests/test_svg_renderer_3d.rex" "$ROOT/qualification/test_mlgraph_cylinder.svg"
"$REXX_BIN" "$ROOT/tests/test_svg_views.rex" \
  "$ROOT/qualification/test_mlgraph_view_shape.svg" \
  "$ROOT/qualification/test_mlgraph_view_timex.svg" \
  "$ROOT/qualification/test_mlgraph_view_timey.svg" \
  "$ROOT/qualification/test_mlgraph_cartesian2.svg"
if [[ -n "$ML_ROOT" ]]; then
  "$REXX_BIN" "$ROOT/tests/test_pattern_adapter.rex"
  "$REXX_BIN" "$ROOT/tests/test_temporal_pattern_adapter.rex"
  "$REXX_BIN" "$ROOT/tests/test_temporal_market_graph.rex"
  "$REXX_BIN" "$ROOT/tests/test_difference_annotations.rex"
  "$REXX_BIN" "$ROOT/tests/test_wobbly_adapter.rex"
  "$REXX_BIN" "$ROOT/tests/test_wobbly_svg.rex" "$ROOT/qualification/test_mlgraph_wobbly.svg"
fi
if [[ -n "$FOREIGN_ROOT" ]]; then
  "$REXX_BIN" "$ROOT/tests/test_matplotlib_renderer.rex" \
    "$ROOT/qualification/test_mlgraph_matplotlib_polar.png" \
    "$ROOT/qualification/test_mlgraph_matplotlib_spacetime.png"
  "$REXX_BIN" "$ROOT/tests/test_matplotlib_views.rex" \
    "$ROOT/qualification/test_mlgraph_matplotlib_view_shape.png" \
    "$ROOT/qualification/test_mlgraph_matplotlib_view_timex.png" \
    "$ROOT/qualification/test_mlgraph_matplotlib_view_timey.png"
  if [[ -n "$ML_ROOT" ]]; then
    "$REXX_BIN" "$ROOT/tests/test_matplotlib_temporal_renderer.rex" \
      "$ROOT/qualification/test_mlgraph_matplotlib_temporal.png"
    "$REXX_BIN" "$ROOT/tests/test_wobbly_matplotlib.rex" \
      "$ROOT/qualification/test_mlgraph_wobbly.png"
  fi
fi
