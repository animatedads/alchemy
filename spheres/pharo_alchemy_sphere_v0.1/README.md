# Pharo Alchemy sphere — operational status 2026-10-29

Owner: CHATGPT; Rasen Falcon lane: pharo-alchemy (OWN-00001818).

Resident ooRexx ↔ Pharo object bridge, not JSON RPC. Pharo is authoritative for selectors and doesNotUnderstand:, ooRexx for UNKNOWN, retained Rexx objects and live methods. Native registry uses generation, retain/release, pin/revoke and synchronous call-thread reentry. Inspection is observational, not a dispatch cache.

Dependencies: ooRexx 5.3.0 r13196, Alchemy Foreign Object v0.2, Alchemy Objects v0.8.1, Crypto v0.8.3, Foreign Runtime v0.22.6, Pharo 12. Version upgrades require fresh closure qualification.

Repository: packages/oorexx_pharo_alchemy; sphere: spheres/pharo_alchemy_sphere_v0.1. GitHub PR #23 tracks dev16 source synchronization; the canonical LLM Gopher sphere editor has not qualified this directory.

Evidence: dev15 and dev16 C11 selector regressions previously PASS (2026-10-23); not rerun 2026-10-29. dev13 nested integer reentry historical claim only; full arbitrary-object dispatch, reversible identity, mutation, exception distinction, shutdown races, wrong-thread rejection NOT_RUN. Do not promote to accepted without real runtime evidence.

Delivery order: reconcile package tree to dev16, compile C11 ABI/selector tests from Git, run Pharo 12 + ooRexx integration with exact dependencies, then sphere validate/lint/package. Autobuilder is stopped; do not depend on it.

Critical-path relationship: this bridge is not the owner of website, SMTP/IMAP, HTTPS, LDAP, or MI↔MU XTP deployment. It must not block those services; no production deploy claim is made here.
