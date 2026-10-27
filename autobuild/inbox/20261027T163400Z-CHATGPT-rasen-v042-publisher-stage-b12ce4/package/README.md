# RasenFalcon website and delivery authority — Git source v0.4.1

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

## v0.4.1 publication-safety correction

Preview always emits `noindex,nofollow`, even when an editorial page is marked approved. Production builds now unconditionally fail closed pending a real authenticated CMS/Brand/Wire release-receipt verifier; local names, timestamps, content hashes or editable approval fields do not confer that authority. Three regression tests added. The existing private NOC/Office mTLS, gateway and operational contracts are carried unchanged. Source candidate only; neither approved CMS publication nor live deployment is claimed.


## v0.4.2 — Publisher-to-site candidate staging

The original site compiler now provides an explicitly offline `stage-publisher` command for Website Publisher v0.3 export/0.1 and its native-record/0.2 read-back. This safely produces a separately staged nine-page candidate, normalized to `status=candidate` with source SHA-256 lineage, then allows an isolated noindex preview via `build --content-dir ... --output-dir ...`.

See `website/docs/PUBLISHER_HANDOFF_V0.2.md`. This is no substitute for an authenticated ooRexx CMS or Brand/Wire release approval, and production remains DENIED. The original v0.4 private NOC/Office boundaries and operational contracts are unchanged.
