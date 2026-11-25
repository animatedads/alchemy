# xtpd_bootstrap v0.1-dev1 — qualification

- Architecture: Tom Dyer.
- Coding: ChatGPT (src/XtpRoleBootstrap.cls, tests/test.rex, test.sh, README.md).
- Qualification and this file: Claude (Opus 5.5), 25 November 2026.
- Wrapper tests/run_tests.sh and tests/qualification/real_store.rex: Claude (Opus 5.5).
- ChatGPT's source is unchanged. It was received as xtpd-bootstrap-v0.1-dev1.zip, SHA-256 439ecbaf687bbc07ee824e4a4d86fa741989343c4f8bd9421f05fe6673deb6be.

## Verdict

Accepted as a source component for xtpd. It is not a field-qualified node component. Grid item 1 is not done.

## What was run

All runs used the Ubuntu 22.04 build container (ooRexx 5.3.0) with the published kits oorexx_logging v0.7 and oorexx_crypto v0.8.3.

1. ChatGPT's suite: 34 PASS, SUITE PASSED. This reproduces ChatGPT's recorded result.
2. Five controls. Each one breaks the source on purpose and checks that the suite fails.

   | Control | Break | Suite fails at |
   |---|---|---|
   | M1 | drop the newer-than check | replay |
   | M2 | report the spare as FRESH | stale spare |
   | M3 | skip the boot signature check | invalid initial signature |
   | M4 | clear the quarantine after a failed store | quarantine after publication failure |
   | M5 | allow key-list changes | no key rotation |

   With the original source restored, the suite passes again.
3. tests/qualification/real_store.rex: 8 PASS. It drives XtpRoleFile with the real AtomicFile, using the native provider built in the container with FULL durability and noFollow. ChatGPT's suite stubs this step.
   - A publication is accepted and the exact envelope is on disk.
   - A restart reads the published record.
   - Publishing through a symlink is refused (PUBLICATION_UNCERTAIN): the target is unchanged and the runtime is quarantined.
   - Options that are not FULL are refused.
4. Autobuild runs tests/run_tests.sh, which is the suite against the repository's own kits. real_store.rex needs the AtomicFile native library, so autobuild does not run it. It is recorded here as a container run.

## Findings

All of these fail closed. None blocks acceptance.

- F1 (nit). XtpRoleFile~load reads through a symbolic link, but replace refuses one. A boot from a symlinked role file succeeds, and its first update is then refused and quarantines the runtime. xtpd will refuse a symlinked role file at configuration time, as it already does for services.txt and peers.txt.
- F2 (nit). If the store raises a syntax error during offer, the result is INVALID_OR_FAILED rather than PUBLICATION_UNCERTAIN. The runtime is still quarantined, because the flag was set before the write.
- F3 (documented by ChatGPT). XtpTestRoleVerifier is a shared-key HMAC. Anyone who holds the test key can also sign. It is a test boundary only, until the real Auth, which R1 excludes.
- F4 (documented). The probe is only as good as its adapter. With the XTP service keys of today, an answer is authenticated as coming from a holder of the service key. It is not authenticated as coming from that one node. Per-node proof needs the real Auth.

## Who does the host binding

The xtpd side is owned by Claude (Opus 5.5), as the author of xtpd:
- the xtp.roles exec-hook service and roleExchange~fetchRole;
- the LDAP role probe (ldapRoleProbe~confirms);
- loading the role file at xtpd start, so that READY comes only from FRESH.

These go into oorexx_xtpd v0.1-dev2.

Self-score for this qualification: 8/10. The real AtomicFile and the controls are covered. No real XTP session or LDAP probe was run, because those belong to xtpd dev2.

Claude (Opus 5.5)
