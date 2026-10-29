# RasenFalcon website and delivery authority — Git source v0.4

A complete **editable** Website Builder v0.1 source tree (`website/`) and the
v0.4 RasenFalcon deployment/contract handoff (`handoff/`). The original nested
Website Builder ZIP is deliberately expanded, not carried as an opaque archive.
`handoff/public_site/github_source.lock.json` preserves each source SHA-256 and
the exact original ZIP SHA-256. No private keys or device certificates are present.

Nine drafted public pages compile under `website/tools/site.py`; publication is
**denied** until explicit per-page approval. The `website/site/` tree is a noindex
static preview, not an active release. The native HTTPS adapter is source only.

NOC and Office have separate native ooRexx HTTPS instances, distinct owner-private
server certificates, mandatory device mTLS and LDAP/Access Permissions. No
fallback. Application schedules use BashQueues cron jobs; the minute tick may be
woken by systemd timer, not cron/crond. See `handoff/contracts/` for policy.

This is an **acceptance candidate** for Alchemy Autobuild, not live deployment.
The handoff `deployment/deploy.sh` remains a review-gated skeleton. Missing CMS,
Brand/Wire publication, accepted HTTPS runtime pin and production TLS/network
qualification remain NOT_RUN/NOT_QUALIFIED.

## Local checks

```bash
bash run_tests.sh
python3 website/tools/site.py validate
python3 website/tools/site.py build --mode production  # expected to fail
```

## Source boundaries

`website/` public site source/preview, `handoff/` operational acceptance contracts.
Do not merge this intake branch into `main` manually. Autobuild is responsible
for testing and promoting to `packages/rasenfalcon_delivery_v0.4` if accepted.

## v0.4.3 — source-lock reconciliation and repeatable verification

The 2026-10-28 independent test found that `handoff/public_site/github_source.lock.json` was not refreshed after v0.4.1/v0.4.2 source changes. v0.4.3 refreshes the **current source** SHA-256 map for all 28 owned website files without changing the original builder ZIP's historical hash or any HTTPS/CMS publication claim. A new source-lock tool, eight regression tests and `handoff/public_site/SOURCE_LOCK_RECONCILIATION_V0.4.3.md` document the boundary. The local suite is 18 website + 21 handoff tests, PASS; GitHub Autobuild acceptance and live runtime qualification are separate.

## v0.4.4 — General Deployment review stage

Public preview generation and a **non-production, local review-only stage** now use the existing General ooRexx Deployment v0.1-dev4 POSIX backend (`bin/deploy_tree.sh`) with an explicit external provider path. The new adapter verifies source integrity before staging, refuses non-temp workspace destinations, verifies all 15 staged files and nine noindex pages, detects tampering and never installs or starts a service. See `handoff/deployment/GENERAL_DEPLOYMENT_STAGING_V0.4.4.md` and `handoff/deployment/REVIEW_STAGE_EVIDENCE_20261029.json`.

The actual `RF_ROLE=public check-release` still refuses installation: no reviewed `roles/public/manifest.tsv`, service list, native HTTPS unit/probes and release qualification. Source-only != staged locally != installed != running. No production release, DNS, TLS or private-service changes were made. The supplied General Deployment dependency is not embedded.

## v0.4.5 executable public HTTPS content qualification

`website/deploy/site_contract_probe.sh https://rasenfalcon.com` now verifies real TLS and exact 9-page/4-asset SHA-256 content against the intended local build, not merely 200 codes. A local ephemeral TLS fixture qualifies negative trust, hostname, redirect and content tampering. No real host was contacted; CMS/Brand/Wire release approval and private NOC/Office mTLS remain separate hard gates. See `website/deploy/HTTPS_CONTENT_QUALIFICATION.md`.
