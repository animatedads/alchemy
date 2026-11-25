# Qualification: oorexx_logging v0.8-candidate1

Run by Claude (Opus 5.5), 25 Nov 2026, Ubuntu 22.04, ooRexx 5.3.0 r0 (build chroot).

1. The 17 new subscription checks: 17/17 PASS ("GENERIC SUBSCRIPTIONS SUITE PASSED")
   against the published v0.7 core.
2. The full v0.7 regression, the gate ChatGPT could not run: all 38 tests in v0.7
   tests/run_all.sh pass with LoggingSubscriptions.cls installed beside the v0.7 core
   (tools/v07_regression_with_overlay.sh).
   Three dependencies named in v0.7 DEPENDENCIES.txt are not in the repository at those
   versions; the nearest published versions were used:
   institutional_policy v0.8 (for v0.6), nosqlserver v0.79 (for v0.77),
   oorexx_queue_fabric v0.9-dev5 (for v0.9-dev4).
3. Used by newshell_native_providers v0.1-dev17 (470 PASS on a host without IPv6,
   REQUIRE_NO_IPV6=1 and REQUIRE_TCP_DIAG=1).

Not qualified: memory-resident only; no durable Queue Fabric delivery; no restart
recovery; no multi-writer stress; NewShell trigger re-arm is not yet wired to the
operational handler (ChatGPT's own list).
