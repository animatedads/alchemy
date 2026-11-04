# Changelog

## v0.1-dev4 — 2026-10-29

- Added `firewall reconcile` through the Cloud Control authority backend.
- Added exact non-empty source-set transport via `--sources CIDR[,CIDR...]`.
- Kept reconciliation unavailable through direct provider-cli mutation so provider semantics stay in Cloud Control.
- Fixed JSON quote/backslash/newline escaping and matching parser escape handling; provider stdout containing JSON now remains valid nested result data.
- Added nested-special-character JSON regression and cross-package Console -> Cloud Control -> provider fixture qualification.
- Reran the complete suite and source/standalone compilation under exact ooRexx 5.3.0 r13196.

## v0.1-dev3 — 2026-10-28

- Added `alchemy.cloud-control/0.1 RESOURCE` as a first-class mutation backend.
- Added `--backend auto|cloud-control|provider-cli` and `--cloud_control PATH`.
- Kept read-side provider inventory independent and labelled read/mutation provenance separately.
- Preserved PLAN/APPLY and exact destroy confirmation before delegation.

## v0.1-dev2 — 2026-09-06

- Established the qualified five-provider console, normalized inventory/firewall results, plan-first mutation, workspace-safe argv transport and direct ooRexx API.
