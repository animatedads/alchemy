# Financial evidence observer — dev9

## Purpose and authority boundary

Observed charge ≠ authorized purchase, ≠ external invoice authentication, ≠ settled expense. The original Cloud Economics paper accounts remain a separate simulation. This observer is local, read-only toward upstream providers; it accepts caller-supplied JSONL, never contacts providers, mutates financial accounts or commissions infrastructure. It is **not** a substitute for the platform Accounting Core, LDAP, native HTTPS, queue messaging or the authoritative provider billing system.

## Contract

Each JSONL record is `cloud.economics.financial-evidence/0.1`. Supported kinds: `BASELINE` (unmanaged estimate, exact decimal string amount, explicit policy, `like_for_like=true`, expected charge count), `USAGE` (exact decimal quantity/resource/unit), `CHARGE` (reported amount, invoice ID, line ID, `ESTIMATED` or `INVOICED`). All records require `id`, `case_id`, `job_id`, `lease_id`, `start`, `end`, `currency`, `source_system`, `source_ref`, `source_sha256`, `source_class` (FIXTURE or UNVERIFIED), and `observed_at`. Identical case IDs must have an identical workload/lease/period/currency scope. Foreign exchange, tax, credits, refunds, account discounts and correction adjustments are **not implemented**; do not quietly net these away.

Input values of money and usage are exact, finite decimal strings with up to six decimal places; floats, NaN and signed values are rejected. The observer rejects unknown fields and JSON duplicate keys, id-equivalent but content-different evidence, duplicate baseline, invoice-line double allocation and altered scope. SQLite writes use `BEGIN IMMEDIATE` and `synchronous=FULL`; the local SHA-256 journal chain is audited before and after batch insertion. This is tamper *detection*, not external authenticity nor an independently anchored history; a malicious DB editor could rewrite the entire chain or truncate its tail. Only a separately governed external attestation system can elevate source trust.

## Interpret report statuses

`INCOMPLETE_EVIDENCE`: missing/insufficient baseline, usage or complete set of INVOICED lines. No comparison number.

`UNVERIFIED_COUNTERFACTUAL_DELTA`: all required caller-reported observations exist. `reported_delta_not_realized = baseline_estimate - reported_provider_charge` is a hypothetical model comparison and is **never realized savings**.

`realized_savings` is always `null`; `external_source_verified=false`. Providers may bill later, issue credits/taxes, bundle charges or amend line items. Do not turn a local hash-chain validation into proof the provider emitted a line. No FX conversion is attempted.

## Example

```sh
export CLOUD_ECONOMICS_STATE=/var/lib/cloud-economics
./tools/cloud-cost reconcile-ingest fixtures/financial_evidence.jsonl
./tools/cloud-cost reconcile-audit
./tools/cloud-cost reconcile-report case-64G
```

## Next authority integration

Use the estate's authenticated, read-only billing adapters and native HTTPS/LDAP/secret-broker identities, then obtain authoritative complete billing-period consumption with exact quantity units and accounting policy for credits/adjustments. Require case/job/lease/owner epoch provenance and authoritative invoice line attestation before ever displaying *realized* savings. Any future mutation of financial books belongs to Accounting Core, not this observer. Connect Selector may carry this same semantic interface via DirectCall/JSON-RPC/Queue Fabric when its actual contract is verified.
