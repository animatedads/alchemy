# Architecture Intentions v0.1-dev11 qualification ledger

Date: 2026-10-29

## Verified in this packaging session
- Historical dev10 source recovered from the user-provided ZIP; source changes for dev11 are two independent classes, three test scripts, package manifest/runner/README and one architecture document.
- JSON schema/catalog/examples and `PACKAGE.json` parse; Bash runner `bash -n` clean.
- Strict ZIP CRC integrity, SHA-256 manifest consistency and no duplicate archive paths verified.
- `ArchitectureRasenFalconBaseline` includes separate public, private, mail and internode gate requirements; public website does not inherit LDAP. Service results are evidence-only, not live activation claims.
- ConnectSelector dev8 Library README/CHANGELOG inspected (authenticated route policy) but its runtime qualification is **NOT_RUN** in this session.

## Not run / not asserted
- Native ooRexx 5.3.0 r13196 test execution: **NOT_RUN** — interpreter binary unavailable in this container. `tests/test_service_readiness.rex`, including its injected synthetic verifier and fail-closed negative scripts, has not been executed here. Previous dev10 tests are historical only.
- Production HTTPS/LDAP/SMTP/IMAP/XTP or deployed target tests: **NOT_RUN**. No live service inspected, started, mutated or declared active.
- Actual SSC accepted dependency lock, NotNotes document write, human sign-off and deployment activation: **NOT_RUN**.

## Security boundary
The candidate evidence payload does not grant rights. `admitEvidence()` requires an external host-injected verifier with exact project, service, gate and evidence-authority claims. Output retains only public proof and evidence reference fields; the service always reports `DESIGN_ONLY_NO_LIVE_ACTIVATION`, even if every gate receives admitted proof.
