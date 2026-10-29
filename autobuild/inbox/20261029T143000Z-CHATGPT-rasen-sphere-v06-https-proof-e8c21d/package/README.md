# RasenFalcon Gopher engineering sphere v0.6 — 29 October 2026

Continuation of the v0.5 native General Deployment review stage. **Autobuilder is offline**: this submission is committed source on a managed Git intake branch, not accepted main or live host deployment.

### Executed locally
- Website v0.4.5 source: `18/18 PASS`; RasenFalcon handoff/deployment: `38/38 PASS` with General Deployment v0.1-dev4 locally available.
- Public HTTPS integrity verifier: `9/9 PASS` using ephemeral localhost TLS fixtures; checks all nine content page bodies plus four static assets, TLS chain/SNI/hostname/fingerprint and response digest, with negative cases.
- Source lock refreshed for 30 owned website files; original source archive identity preserved.
- Independently authorized v0.4.3 retest: CLAUDE-PC REQ-00001283/00001289 confirmed 18/18 + 21/21 tests and independent validate/source-lock PASS; installation NOT OBSERVED.

### Github source and runtime truth
- v0.4.5 candidate: [Git source](https://github.com/animatedads/alchemy/tree/autobuild-submit/20261029T140000Z-CHATGPT-rasen-v045-live-https-content-proof-09f62a); ready commit `3199b2f48c625e58c69221c3416213e728da4e67`.
- v0.4.5 archive SHA-256 `30d8122e39b481d16bc3b313718dd6ab530c9132a3a778dd2fefddc65fdfb5bd`.
- **SOURCE_SUBMITTED**, local General Deployment staging from v0.4.4 **STAGED_REVIEW_ONLY**, target install **NOT_OBSERVED**, public native HTTPS **NOT_PROBED**, production CMS/Wire approval **BLOCKED**.
- The public verifier is not private mTLS. `noc` and `office` each require distinct private-CA native ooRexx HTTPS servers, mandatory device client certs, LDAP active identity and HTTPS_LOGIN. No fallback to Apache/Nginx or public CA for private endpoints.
- Gateway native SMTP/IMAP, LDAPS identity, MCP, XTP network and BashQueues cron maintain their **separate ownership**; this sphere never claims those services active.

Read `packs/rasenfalcon/articles/rasenfalcon.live-https-integrity.json` and `rasenfalcon.deployment-stage.json` for precise evidence and boundaries. Publication is not inferred from a successful TLS GET or a read-only staged preview.
