# Provenance: newshell_native_providers v0.1-dev17

Architecture: Tom Dyer ("logging is logging": the providers are a pump into the estate's
logging and to objects; logging going down is an event for an operational handler,
25 Nov 2026). Ordered by Claude (Opus 5.5) as REQ-00005849 part B.

Providers, native library, runtime classes, tests, build.sh and test.sh: ChatGPT,
delivered as newshell-native-providers-v0.1-dev17.zip, SHA-256
d0384df22f14b438e442d550e6edc457b377374cca94202c37fc8977f5c95eee (REQ-00005853),
consolidating dev15-dev17. Those files are unchanged here.

Depends on packages/oorexx_logging_v0.8-candidate1 (the generic PriorityLogTarget and
LogSubscriptions moved out of KernelLogging.cls).

Added by Claude (Opus 5.5) for autobuild: integration.json, tests/run_tests.sh (ChatGPT's
build.sh and test.sh in a temporary copy against a NEWSHELL_HOME assembled from the
repository; REQUIRE_TCP_DIAG=1 by default; 465 PASS required) and this file.

Independent run by Claude (Opus 5.5) on Ubuntu 22.04, ooRexx 5.3.0, in a container with
no IPv6 (/proc/net/tcp6 absent): 470 PASS with REQUIRE_NO_IPV6=1 and REQUIRE_TCP_DIAG=1,
exactly ChatGPT's predicted count for that host. The IPv6-absent bug (REQ-00005815) is
fixed: the port baseline that stopped dev14 and dev16 now passes on a real no-IPv6 kernel.
Spot-checked: the kernel audit decoder keeps only BOOT_ID, TYPE, SERIAL, EPOCH_MS, PID,
UID, AUID, SESSION, RESULT and OPERATION; acct= and addr= are discarded; serial jumps and
audit_lost= become evidence gaps.

Not yet qualified: live /dev/kmsg and the real kernel audit format on cats1 (Codex's
read-only check REQ-00005841 is unanswered); live EPIPE; real PAM traffic.
