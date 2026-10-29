## dev9 evidence boundary validation (2026-10-29)

- `python3 tests/test_financial_evidence.py`: 17 PASS (stdlib observer; fixture evidence only).
- `python3 -m py_compile tools/financial-evidence tests/test_financial_evidence.py`: PASS.
- `bash -n tools/cloud-cost tests/run.sh`: PASS.
- `./tools/cloud-cost reconcile-ingest fixtures/financial_evidence.jsonl` and `reconcile-report`: expected `reported_delta_not_realized=0.420000` in fixture; no realized savings.
- ooRexx 5.3.0 is not present in the current qualification environment. Previous dev8 native suite is **not rerun**; independent native qualification remains required. No live provider/Queue Fabric/LDAP/HTTPS tests.

# Cloud Economics qualification (dev7)

Date: 2026-10-08
Runtime: supplied ooRexx 5.3.0 r13196 (Linux x86-64 debug package), executed with LD_LIBRARY_PATH set to its local library root.

Native tests:
- dev5 running-job marginal migration (checkpoint mobility, prepaid compute, transfer, billing quanta, cooldown, deadlines, jurisdiction, capacity, advisory-only migration-tick snapshot isolation, negative tariff/receipt tamper fail-close) — PASS.
- Existing dev3 planner/scheduler, Generalized Compute Intentions, forecast and deadline validation — PASS.
- dev4 whole-job economics (billing quantization, risk, checkpoint overhead, staging I/O, storage, segmented Memory Fabric traffic, deadline and missing-term admission) — PASS.
- dev4 continuous paper controller opt-in pricing, atomic snapshot activation, semantic rejects, SHA-256 checksum tamper gate, preview isolation, replay, balanced long-decimal ledger, cost-receipt tamper audit and missing profile hold — PASS.
- Native dev2 authority bridge using actual Job-to-Node Allocator, Memory Fabric and Generalized Compute Intentions classes — PASS.
- Existing Instrumentation Mesh adapter — PASS.
- dev3 AWS and Google Cloud read-only mocked public-source observation and source-provenance gates — PASS.
- Existing paper ledger idempotency, budget/capacity contention, interrupted posting repair and corrupt ledger freeze — PASS.

Validation commands:

```sh
bash -n tools/cloud-cost tools/poll-providers tools/aws-spot-readonly tools/gcp-catalog-readonly tools/azure-public-readonly tests/run.sh tests/test_whole_job_cli.sh tests/test_migration_cli.sh
export REXX_BIN=/path/to/oorexx-5.3.0-r13196/bin/rexx
export GENERALIZED_INTENTIONS_ROOT=/path/to/oorexx_generalized_compute_intentions_v0.1-dev3
export JOB_NODE_ALLOCATOR_ROOT=/path/to/job_node_allocator_v0.6-network3
export MEMORY_FABRIC_ROOT=/path/to/oorexx_memory_fabric_v0.1-dev7
export INSTRUMENTATION_MESH_ROOT=/path/to/oorexx_instrumentation_mesh_v0.1-dev3
export CRYPTO_ROOT=/path/to/crypto
./tests/run.sh
```

Caveats: provider API calls are mocked. No genuine estate route and mobility authorization, no genuine cloud capacity availability, bill, ML backtest, purchase, job migration, distributed active-writer fencing, route transport, or new native provider rights are claimed. The included fixtures are fabricated scenarios, not current provider prices.

## Dev6 native estate qualification

`tests/run.sh` runs the added native gate test when `JOB_NODE_ALLOCATOR_ROOT`,
`MEMORY_FABRIC_ROOT`, `CRYPTO_ROOT` and `GENERALIZED_INTENTIONS_ROOT` resolve.
The source lease is issued by a real `JobNodeAllocator`; lifecycle states are
read via its published native registry. The upstream `observe` method is
currently broken on the supplied debug runtime (see dev6 documentation).
All financial/write/observer regressions are unchanged.

## Dev7 native continuation qualification — 2026-10-11

Full `tests/run.sh` using supplied ooRexx r13196, JNA network5, Memory Fabric dev10, Migratable Job v0.2.2 extracted from latest Audio V9, Generalized Compute Intentions dev3, Instrumentation Mesh dev3 and the crypto dependency bundled with RTO2 Grid dev13: PASS, including new `tests/test_migration_continuation.rex` and existing 10 regression groups. The mock AWS, GCP and Azure observers remain mocks.

Direct JNA network5 upstream lifecycle and runtime reconciliation tests fail, as recorded in `docs/NATIVE_CONTINUATION_AUTHORITY_DEV7.md`. Cloud Economics neither patches nor claims qualification of these upstream methods. Byte count conversion in native Migratable Job records is approximate under default numeric precision. All effects remain disabled.

Set `MIGRATABLE_JOB_ROOT` to the extracted `migratable_job_v0.2.2` folder to enable native continuation test; dependencies are optional to standalone paper planning, never silently replaced by stubs.

## dev8 qualification (2026-10-23)

`python3 tests/test_migration_status.py`: status ingestion, idempotency,
retained out-of-order evidence, mutation rejection, identity/epoch and
checkpoint invariants, audit tamper and CLI evidence checks.
`bash -n` for the Bash CLI and `python3 -m py_compile` for the status consumer.
Native ooRexx is not installed in this tool runtime, so dev7 native regression
results are inherited, **not** a dev8 native PASS claim.
