# Customer Service Readback — Legacy ASR Evidence Bridge v0.1-dev2

Additive to dev1. The A02 83 existing letter/NATO/numeric clips are candidate work definitions, not verified speech assets.

This corrects an integration defect: the older Google/Azure normalizers omit the source and audio SHA-256 bindings required by the legacy reviewer. `src/asr_evidence.py` imports independently obtained provider JSON against a pinned work plan, rejecting ambiguous batch sources, invalid/missing offsets, out-of-range words and hashless job records.

Run:
```
python3 src/legacy_recovery.py plan --prepared /path/A02_prepared/manifest.json --vocab examples/readback_vocabulary.json --output /tmp/readback_plan.json
python3 src/asr_evidence.py --plan /tmp/readback_plan.json --clip NATO_A --provider google --response /path/NATO_A_google.json --output /tmp/NATO_A.words.json
python3 src/legacy_recovery.py review --plan /tmp/readback_plan.json --clip NATO_A --transcript /tmp/NATO_A.words.json --output /tmp/NATO_A.review.json
python3 -m unittest discover -s tests -v
```

No API calls, provider authentication, raw video transfer, asset approval or dispatch are performed. Human audio/video review and authorised service permissions remain required. Storage Fabric owns source bytes; Migratable Job and Job-to-Node Allocation own mesh execution.

Qualification 2026-10-29: 26 Python tests PASS (15 importer + 11 legacy); real A02 preparation manifest produced 83 candidate jobs out of 227 clips; integration with a synthetic Google recognition response reached review-only. Live cloud transcription, MediaPipe inference and mesh dispatch are not qualified.
