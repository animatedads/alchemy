# dev14 requalification status

Date: 2026-10-23

dev14 changes only the outbound compatibility projection path:

- `LlmCodingJsonCodec~encodeTurn()` no longer calls `turn~asDirectory` directly.
- It delegates to its configured `LlmCodingBoundaryAdapter`.
- `test_codec_boundary_delegation.rex` asserts that the exact live
  `LlmCodingTurn` object reaches the boundary before JSON projection.
- No Coding Intention source was changed.

The complete r13196 environment record in `QUALIFICATION_r13196.txt` is the
accepted dev13 evidence. The exact ooRexx 5.3.0 r13196 package used for that run
was referenced from an earlier conversation upload but did not have a
downloadable backing file in the 2026-10-23 execution environment. Therefore
the full environment suite was not rerun here and no dev14 runtime PASS is
claimed.

Required next qualification when the exact runtime/dependencies are available:

```sh
OOREXX_ROOT=/path/to/extracted-r13196 \
CODING_INTENTION_ROOT=/path/to/coding-intention-dev13 \
INTENTION_SERVICE_ROOT=/path/to/intention-service-dev9 \
  ./tools/run_environment_test.sh
```

The expected architectural invariant is stricter than dev13: outside tests and
the boundary adapter itself, Workbench source must not call
`LlmCodingTurn~asDirectory` to prepare outbound/API data.
