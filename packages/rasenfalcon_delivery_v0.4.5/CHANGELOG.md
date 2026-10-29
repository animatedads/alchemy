# Changelog

## 0.4.5 — 29 October 2026
- Assemble the owned public website files and ooRexx adapter into a reproducible 16-file manifest slice for the Rasen Falcon installer.
- Independently verify file integrity, site noindex and identity; reject tampering, escapes, stale or synthetic authority.
- Add 13 executable regression tests. The native HTTPS and service test closure remain external and unqualified; installation gate stays closed.
- Record independent successful v0.4.3 retest from CLAUDE-PC via Rasen Falcon lane.

# RasenFalcon delivery changelog

## 0.4.4 — 29 October 2026
- Reuse external General ooRexx Deployment dev4 `deploy_tree.sh` to stage only nine-page noindex public preview into a constrained scratch workspace.
- Implement source-lock verification, isolated build, digest/route/robots validation, stage/verify evidence and drift detection.
- Add eight regression tests and document exact source-only/staged-local/installed/running evidence boundaries.
- Confirm public installation preflight denies missing reviewed release manifest; no system install or activation.

# Rasen Falcon delivery changelog

## 0.4.3 — 28 October 2026
- Correct source checksum drift identified by independently executed test REQ-00001007.
- Update exact current website source digest map (28 files; previously 26), retaining original builder ZIP provenance separately.
- Add explicit read-only check and reviewed refresh operation; reject extra/missing/modified and symlinked source.
- Add 8 source-lock regression tests. Local website 18/18 and handoff 21/21 PASS.
- Keep publication, HTTPS, NoSQLServer and RexxOS live status NOT_RUN/NOT_QUALIFIED.

## 0.4.2 — 27 October 2026
- Offline Publisher v0.3 candidate staging and preview (18 site tests).

## 0.4.1 — 24 October 2026
- Always noindex editorial preview; deny local claim-based production builds.
