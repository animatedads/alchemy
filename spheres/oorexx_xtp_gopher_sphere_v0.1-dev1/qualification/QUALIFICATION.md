# XTP Sphere v0.1-dev1 qualification

Generated 2026-10-23. All source archives independently SHA-256 checked in SOURCE_MANIFEST.json.

- Structural article/schema and cross-link verification: run `python3 tests/test_sphere.py`.
- Offline provisioning candidate contract: 19 Ed25519 positive/negative unit tests re-run from extracted candidate zip 2026-10-23; passed.
- LLM Gopher `sphere validate/lint/context`: only mark PASS after running against an installed Gopher. No installed Gopher runtime is asserted here.
- Native XTP v25 real remote session crypto: NOT QUALIFIED.
- XTP gateway atomic dual registry PREPARE/ACTIVATE: NOT IMPLEMENTED.
- Durable quorum authority deployment and 2-of-3 fault tests: NOT QUALIFIED.
- ED209 raw36 and direct L2 commissioning: NOT QUALIFIED.

Do not treat the checked source ZIP hashes as proof of CI acceptance, production release, or ED209 field qualification.
