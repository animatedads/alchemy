# rexxos_mi_launcher v0.1-dev1 — qualification

- Architecture: Tom Dyer.
- Coding: ChatGPT (src/MiLauncher.cls, bin/mi-namespace-exec, bin/stage-image.sh, tests/test.rex, test.sh, README.md).
- Qualification and this file: Claude (Opus 5.5), 25 November 2026.
- Wrapper tests/run_tests.sh and tests/qualification/namespace_probe.sh: Claude (Opus 5.5).
- ChatGPT's source is unchanged. It was received as rexxos-mi-launcher-v0.1-dev1.zip, SHA-256 c47fa72394395c33de124cc8f1a7ebb13d14092e13c1c313e4ecd36d38c63f27.

## Verdict

Accepted as the controller's MI lifecycle component. Grid item 3 is not done: no image exists yet, there is no runner, and no namespace has been booted on cats2.

## What was run

All runs used the Ubuntu 22.04 build container (ooRexx 5.3.0) with the repository's kits:
- newshell_native_providers v0.1-dev18, built from source;
- oorexx_process v0.1-dev2, built from source;
- newshell_llm v0.1-dev6;
- oorexx_logging v0.7.

1. ChatGPT's suite: 36 PASS, plus a syntax check of both shell helpers. This reproduces ChatGPT's result.
2. Five controls. Each one breaks the source on purpose and checks that the suite fails.

   | Control | Break | Suite fails at |
   |---|---|---|
   | M1 | accept a registration without VERIFIED | unverified registration refused |
   | M2 | do not record a used incarnation | reuse incarnation refused |
   | M3 | stop ignores the incarnation | stale stop refused |
   | M4 | a logging failure never blocks | logging disabled prevents new launch |
   | M5 | no capacity check | capacity bounded |

   With the original source restored, the suite passes again.
3. bin/mi-namespace-exec, run for real (tests/qualification/namespace_probe.sh) on a small prepared root: dash and its libraries, contract-v1 and a runner.
   - Run as root, it refuses (rc 77).
   - A bad MI name is refused (rc 64).
   - A symlinked root is refused (rc 65).
   - Run as an unprivileged account, `unshare` fails with "Operation not permitted": this sandbox forbids unprivileged user namespaces, as ChatGPT's did. The live namespace boot has therefore not been run anywhere yet.

## Findings

None blocks acceptance.

- L1 (environment, first check on cats2). The helper needs unprivileged user namespaces for its dedicated account. On cats2, under R1, run `sysctl kernel.unprivileged_userns_clone` and `unshare --user --map-root-user true` as that account, before anything else in item 3. If either is refused, an MI cannot start on that node by this route.
- L2 (nit). poll traps syntax errors from the registrar, and in ooRexx an interrupt raised inside a method arrives as syntax 4.x. A SIGTERM during a registrar call would then be recorded as an observation gap. The same class of fault was found and fixed in xtpd v0.1-dev2. The fix is to re-raise when the code starts with 4.
- L3 (nit). stage-image.sh writes a tar that is not reproducible: the file order, times and owners follow the build host. Two builds of the same root then give different SHA-256s, which weakens "verify the entire image digest" as a cross-check between builds. `tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner` would fix it.
- L4 (documented). The suite's backend replaces the helper with /bin/sleep, so the suite never runs the helper. Item 3 above runs it.

Self-score for this qualification: 8/10. The suite, the controls and the helper's refusals are covered. The live namespace boot could not run here.

Claude (Opus 5.5)
