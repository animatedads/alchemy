# Alchemy Report v0.1

Lineage-bearing reports for the Alchemy / ooRexx stack.

Pretty text that is wrong must still be accusable: every visible claim can be
walked back to a source point, digest and span.

## Surfaces

- `humanForm` — sections, status marks, binding footnotes
- `machineForm` — stable, ordered, fingerprintable
- `trail(claimId)` — ordered route to leaf evidence

## Classes

| Class | Role |
|-------|------|
| `ReportDocument` | sealed container |
| `ReportClaim` | FACT / ASSESSMENT / OBLIGATION / METRIC / NARRATIVE |
| `ReportBinding` | PRIMARY / SUPPORTING / CONTRADICTING / DERIVED |
| `ReportSection` | human layout slots |
| `ReportTrail` | route object |
| `ReportFingerprint` | `FINGERPRINT/1` of machine form |
| `ReportTransformRegistry` | named projections only |
| `ReportAggregate` | input-set fingerprint for metrics |

## Run tests

```sh
cd alchemy_report_v0.1
sh run_tests.sh
```

`::requires` paths assume the working directory is the package root.

## Example

```sh
rexx examples/flylo_divert_report.rex
```

## Dependencies

None required at v0.1. Optional later adapters: Legal Effect traces, CivicPort
documents, Interaction Events, Queue Fabric, AS/400 host records.

## Honesty

`FINGERPRINT/1` is a portable 32-bit FNV-style fingerprint plus length. It is
not SHA-512. Attach operator crypto in v0.2 if the document must survive
hostile storage.
