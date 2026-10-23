# Cloud Economics / Economic Workload Planning — LLM Gopher sphere v0.1

**Role:** durable architecture, semantics, evidence and continuation guidance for the Cloud Economics component. This sphere is **documentation**, not an executable authority.

Grounded candidate: `cloud_economics_v0.1-dev8.zip`, SHA-256 `8354043fc133ef9b6fdb593ec8d000e278e0748228224464b9ebb7feb485e735`, API `cloud.economics/0.1`. The source candidate was submitted to `animatedads/alchemy` using the Autobuild Git-branch protocol on 2026-10-23. Presence of a submitted branch does **not** prove Autobuild acceptance or production operation.

## Architectural decision

Optimize the **cheapest valid completion of an intention**, not simply the cheapest advertised VM. Only rank candidates that passed the actual eligibility authorities. A quoted tariff does not establish capacity, identity, legal eligibility, a current node lease, a WLU reservation, a checkpoint, a transfer, or purchase permission.

Cloud Economics owns cost estimates, opportunity observations, economic comparisons, forecasts, paper commitments and their local ledger. It does **not** own Queue Fabric, Job-to-Node Allocator, WLU, Memory Fabric, Migratable Job, Connect Selector, cloud-provider credentials, legal/security/access policy, live provisioning, or accounting-system financial settlement.

## Lookup

```sh
gopher --profile cloud-economics context cloud-economics --full
gopher --profile cloud-economics open cloud-economics.start
gopher --profile cloud-economics search 'savings' --sphere cloud-economics
```

Profile: `profiles/cloud-economics.json`. Pack: `packs/cloud-economics/`. Articles: architecture, authority, observation, workload cost, migration, financial evidence, intentions, qualification and next work.

## Source and qualification

Source files and version-specific status are enumerated in `evidence/source-baseline.json`. Run `python3 tests/test_sphere.py` for structural and source-inventory checks. This test does not prove Gopher index loading, live provider API retrieval, live status subscription, cloud purchase authority or accounting settlement. Such claims require independent qualification.

## Separation of financial claims

- **Forecast:** a modelled counterfactual, never a realized saving.
- **Paper commitment:** locally simulated decision, never real spending.
- **Observed consumption:** operational measurement without financial settlement.
- **Provider charge/invoice:** financial evidence with jurisdiction, currency and reconciliation status.
- **Realized saving:** only when compatible actual baseline and settled cost evidence are available. The dev8 runtime does **not** calculate this.

Unverified data remain labelled unverified; missing data remain absent, not zero.
