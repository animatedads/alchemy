# Changelog

## v0.1-dev3 candidate — 2026-10-28

- Added `alchemy.cloud-control/0.1 RESOURCE` as a first-class mutation backend.
- Added `--backend auto|cloud-control|provider-cli` and `--cloud_control PATH`; `ALCHEMY_CLOUD_CONTROL` is the automation/Codex environment binding.
- `auto` selects Cloud Control when configured; direct provider mutation remains an explicit development/test fallback.
- Kept read-side provider inventory independent and labels results with read and mutation backend provenance.
- Preserved PLAN/APPLY and exact destroy confirmation before Cloud Control delegation.
- Added backend regression cases; r13196 qualification is pending and dev2 remains the last qualified release.

## v0.1-dev2 — 2026-09-06

- Rebased design against `oorexxapis(20260906-192151).zip` and `sphere(20260906-192150).zip`.
- Unified Azure, Vultr, GCP, AWS and OCI lifecycle/inventory/firewall rule control.
- Added normalized machine and firewall records.
- Added JSON result schema `oorexx.cloud.console.result/1`.
- Added plan-first mutation model and exact machine-destroy confirmation.
- Added standalone `cloudctl.rex` so execution does not depend on caller cwd for `::requires` resolution.
- Added `--workspace` / `OOREXX_CLOUDCTL_WORKSPACE` context override without treating path as authority.
- Added lossless shell/Codex argv transport in `bin/cloudctl`.
- Added direct ooRexx `CloudApp~runTokens(.Array)` API.
- Added provider aliases including `amazon`, `gcloud`, `az`, and `oracle`.
- Made GCP machine handles copyable as `zone/name`.
- Normalized OCI firewall protocols.
- Repaired ooRexx `RESULT` special-variable collision.
- Repaired optional `USE ARG` handling where omitted args are not `.nil`.
- Removed unsafe short-circuit assumptions around provider JSON shapes.
- Repaired JSON escaping strict-character comparisons.
- Added fake-provider regression qualification across all five providers.
