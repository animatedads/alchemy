# RasenFalcon full-stack handoff v0.4 — Website Builder + private mTLS

**Delivery is not a commissioned live service.** All hosts remain untouched.

This integrates the v0.3 nine-lane delivery board with the real preexisting **Website Builder v0.1** (editable nine-page public site), owner-private **separate NOC and Office ooRexx HTTPS instances**, explicit required **device mTLS**, and **BashQueues cron** for scheduled application work.

- `inputs/rasenfalcon_website_builder_v0.1.zip`: exact supplied builder source/preview with its tests, not a fresh site recreation.
- `public_site/builder.lock.json`: precise source hash and known accepted-vs-candidate HTTPS version ambiguity; `public_site/INTEGRATION.md` gives the unfinished CMS/Brand/Wire/approval seam.
- `contracts/PRIVATE_HTTPS_POLICY.json` and `.md`: machine-readable fail-closed cert and service constraints. Public website remains public and cannot route to private app surfaces.
- `deployment/HOSTS.json`: dedicated NOC/Office units and BashQueues scheduling declared; actual `deployment/deploy.sh` is **still** a review-gated skeleton.
- `codex/`: all nine implementation assignments updated; GitHub issues #6, #7, #8, #10, #13, #14 updated separately.
- `tests/`: consistency tests, not native TLS live acceptance.

**Verified:** existing Website Builder suite 9/9 PASS; JSON site validation PASS; unauthorized production build blocked; HTTPS v0.4.7 exact source archive SHA-256 matches builder lock. Full v0.4 handoff tests run separately. No validated live TLS, Wire CMS, LDAP device enrollment or publish approvals; do not mark those PASS.

Canonical source submission rules remain in `https://github.com/animatedads/alchemy/blob/main/GIT_SUBMISSION.md`. Do not deploy or install server keys from this package.

## General Deployment dev5 integration — 29 October 2026

The controller now follows `HOSTS.json` for independent private HTTPS units: NOC requires `rasenfalcon-noc-https.service`; Office requires `rasenfalcon-office-https.service`. A regression test prevents return to the generic-unit mismatch.

General Deployment dev5 supplies the LDAP identity-role builder and relocatable verified ooRexx namespace launcher. See `deployment/GENERAL_DEPLOYMENT_DEV5.md`. Source/staging integration is delivered; live LDAP, mTLS, mail and public cutover remain operator-gated.
