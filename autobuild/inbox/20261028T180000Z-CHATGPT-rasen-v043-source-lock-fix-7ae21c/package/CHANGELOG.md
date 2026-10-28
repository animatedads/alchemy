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
