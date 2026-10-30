# Changelog

## 0.4 — 2026-10-29
- Synchronized the complete Direct Linux dev41 source archive to Git main without semantic edits.
- Rebased Rasen Falcon evidence to v0.4.5 on main and its verified 16-file public role source slice.
- Split public apex readiness from private NOC/Office readiness: LDAP is not a public-site prerequisite.
- Recorded LDAP dev23 PR #71 as open/not merged/not installed; private admission requires active LDAP principal + explicit HTTPS_LOGIN + device mTLS.
- Kept exact HTTPS v0.4.8 runtime/live TLS and live Wire browser roundtrip gates fail-closed.

## 0.3 — 2026-10-29
- Rebased Swing evidence to dev12 and Direct Linux evidence to dev41.
- Closed the old Direct Linux internal version-metadata debt: dev41 VERSION is now correct.
- Added measured gate counts from executable `wire_ui_renderer_conformance_v0.3`: Swing 8/10, Direct Linux 3/10; neither is falsely called full PASS.
- Added Rasen Falcon website/runtime readiness gate over delivery v0.4.4, HTTPS 0.4.8, LDAP dev22 and Wire Application Deployment candidate3.
- Recorded that review staging exists but production is NOT_READY until release admission, exact modified HTTPS runtime/live TLS, LDAP installation/live LDAPS and live Wire browser semantic roundtrip are evidenced.

## 0.2
- Elevated Web/Swing/GTK/Android semantic agreement to explicit conformance contract and Resource Editor publication authority.
