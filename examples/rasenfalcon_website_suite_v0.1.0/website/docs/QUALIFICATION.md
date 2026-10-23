# Rasen Falcon 0.1 — qualification evidence

Date: 2026-10-21. Package: preview website (no deployment).

| Check | Observed | Result |
|---|---|---|
| Source JSON schema, navigation and page fields | 9 pages, all references valid | PASS |
| Editor/agent CLI build | deterministic preview build, JSON result | PASS |
| Python unit suite | 9/9 | PASS |
| HTML escaping | untrusted headline escaped | PASS |
| Production release denial on missing approval | raises release-gate error | PASS |
| Preview index/noindex, no analytics/CDNs | test assertions | PASS |
| Node source check for site navigation | `node --check` | PASS |
| Supplied ooRexx 5.3.0 r13196 debug extracted and run | `rexx -v` returned correct version | PASS |
| ooRexx HTTPS preview adapter syntax | `rexxc server/serve.rex` | PASS |
| Wire authoring fixture syntax | `rexxc` class + compiler launcher | PASS |
| Wire UI JS v0.4-dev6 independent test suite | Node test 50/50 | PASS |
| Dynamic Wire authoring compile | missing accepted Alchemy Objects/Crypto dependency closure | NOT QUALIFIED |
| Public HTTPS live test | RF-008/RF-010 SNI/host isolation and operator approval pending | NOT RUN |
| Browser pixel/manual screenshot QA | browser preview blocked by sandbox policy | NOT QUALIFIED |
| CMS Brand Builder integration | stand-alone accepted service/API not established | NOT QUALIFIED |
| Mail enquiry submit | no verified mailbox/routing | INTENTIONALLY DISABLED |

All success assertions refer only to operations actually executed. The native server and Wire Builder code are not claimed as end-to-end qualified. The site is not deployed and is not indexed.

## Expected next independent acceptance

1. Exact executable CMS Brand Builder service/API and authorisation contract.
2. Genuine Resource Editor publication receipts and compiled Wire authoring release.
3. HTTPS Server virtual-host/SNI modifications accepted and runtime-proven on target instance.
4. Reviewed wording, privacy policy, operator identity, and externally verified service contact.
