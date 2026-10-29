# RTO Inspector r142 — trace-request admission and provenance

## Behavioural change

`tools/rto_inspector_import.py` admits deterministic receipt evidence only when the receipt's source name is a project request (`data/inspector-trace-requests/<stem>.json` or `<stem>.json`) and the actual project request exists as a **regular**, **schema-valid** JSON file. The local configured request bytes are fingerprinted with SHA-256 and displayed in the output for audit comparison. Unknown requests, redirected absolute/traversal paths, symlinks, invalid schema and invalid acknowledgements are rejected instead of contributing coverage.

## Separation of evidence classes

1. A configured rule is local intent, **not** a live installed hook.
2. A valid positive-rule Inspector receipt says the named request was loaded, but does **not** cryptographically bind the loaded content to the current local request digest.
3. A snapshot's structured `objects[].class` is an observed class claim, **not** an executed RTO operation.
4. No imported evidence can authorize an operation, establish a deployment, or replace `RTOOperationSecurityContext`.

The absence of a signed receipt and attested host metadata is an explicit `host_attestation: NOT_VERIFIED`. Do not use this read-only importer as a website/mail/LDAP/HTTPS/XTP go-live decision.

## Reproduce

```sh
python3 tests/rto_v105r142_inspector_config_binding_static.py
python3 tests/rto_v105r141_inspector_evidence_truth_static.py
python3 tools/rto_inspector_import.py --root . --live-dir tests/fixtures/inspector-live --json
python3 tools/rto_plan42_verify.py --root . --spec specs/plan42/rto_inspector_live_import.spec.json --json
```

## Limitations

No live ooRexx execution was available in this sandbox. SHA-256 is a fingerprint, not an authentication or an ownership proof. The reports currently have no end-to-end signed receipt/host identity verification. RTO command authority and the Inspector framework source remain untouched.