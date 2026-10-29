# RTO Inspector live artefact import

`tools/rto_inspector_import.py` is the bridge between a later live
`ALCHEMY_INSPECTOR=1` ooRexx run and the static Plan42/RTO evidence reports.
It reads files that Clouseau already wrote and summarizes them for operators and
AI review.

The tool is read-only. It does not run RTO, does not install Inspector probes,
does not load trace requests, and does not make authority decisions. The live
authority boundary remains `RTOOperationSecurityContext`.

## Expected live inputs

Copy or write live Inspector artefacts into `reports/inspector/live` or pass a
custom directory with `--live-dir`:

- timestamped snapshots such as `rto-inspector-CORE-*.json`
- deterministic receipt sidecars such as `.rto-authority-corridor.receipt.json`
- trace request load acknowledgements
- handcuff/security reports
- trigger, source trail, unknown-method, or method trace reports

## Commands

```bash
python3 tools/rto_inspector_import.py \
  --root . \
  --live-dir reports/inspector/live \
  --output reports/inspector/live_import_summary.json \
  --compare-output reports/inspector/live_compare.json \
  --json
```

For static acceptance without a live ooRexx runtime, the package includes a small
fixture directory under `tests/fixtures/inspector-live`.

## Why this is separate from Clouseau

Inspector Clouseau owns instrumentation and report generation. RTO owns its
command-object authority path. The importer only reads Inspector evidence and
checks whether the expected command/authority and filesystem-observe corridors
are visible in the artefacts.