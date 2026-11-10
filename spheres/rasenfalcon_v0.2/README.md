# RasenFalcon Gopher engineering sphere v0.2 — 27 October 2026

This version succeeds `spheres/rasenfalcon` v0.1 without overwriting it. Canonical LLM Gopher ID: `rasenfalcon`.

## Current GitHub state

- `packages/rasenfalcon_delivery_v0.4`: **on main** (tree-verified).
- `spheres/rasenfalcon` v0.1: **on main** (tree-verified).
- `rasenfalcon_delivery` v0.4.2 offline Publisher staging: **source-only Autobuild candidate**, [branch](https://github.com/animatedads/alchemy/tree/autobuild-submit/20261027T163400Z-CHATGPT-rasen-v042-publisher-stage-b12ce4), commit `0718e920eb91b47d608e1754d288eda20fe9e0ff`.
- Autobuild receipt for the cited submission IDs: **not observed** in inspected receipt paths.
- Live CMS/Brand/Wire publication and private NOC/Office mTLS: **NOT_QUALIFIED/NOT_RUN**.
- Production public site: **NOT_DEPLOYED**.

## New continuity

- Library `alchemy_website_publisher_v0.4.zip` SHA-256 `db878df230884e71900dfcdb483d09eab15414d34de8898638de7120cdc9663d`: visual editorial editor, offline candidate export and NoSQLServer v0.90 native snapshot adapter; not an authenticated live CMS.
- Library `website_publisher_gopher_sphere_v0.2.zip` SHA-256 `0ead0662ff955e757d71d2c5bfbd724136d17c2f78e8c5ed156cf7e08e5cda11`: separate Publisher continuity authority. Do not overwrite its lane or code.
- RasenFalcon candidate `stage-publisher` accepts export/0.1 or native-record/0.2 in `CANDIDATE_ONLY`, creates an isolated atomic stage with `staging.json`, strictly strips claimed approval, records native revisions as **unverified**, and keeps preview `noindex` and production **DENIED**.
- The site staging source declares 18 tests, not a verified independent PASS.
- Rasen Falcon MCP `rasenfalcon-website`: original test `REQ-00000481` received `REQ-00000825` **NOT_RUN**; corrected command-complete test-only brief `REQ-00000943` needs named operator approval.

## Binding security and authority

The prior v0.1 service boundaries are unchanged: distinct privately certified NOC and Office native ooRexx HTTPS daemons with mandatory per-device mTLS, no downgrade path; native SMTP/IMAP/LDAP; Wire semantics; exact `ed209zz`/`ed209z` and `ed209cray`/`ed209tops` targets; BashQueues cron with a systemd ticker; and least-presence service withdrawal.

Start Gopher with `gopher --profile rasenfalcon context rasenfalcon --full`. Source and tests in `packs/rasenfalcon/` and `tests/`. The sphere is documentation and qualification, never secret-bearing runtime code.

Publication via `GIT_SUBMISSION.md` has a new versioned destination `spheres/rasenfalcon_v0.2`, because replacing existing accepted source in place is prohibited by Autobuild collision rules.
