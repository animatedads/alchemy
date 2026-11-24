# Provenance: newshell_native_providers v0.1-dev14

Architecture: Tom Dyer (including the request for PAM/AUID/PID correlation and registered process
memory and network observation). Providers, native library, runtime classes, tests, build.sh and
test.sh: ChatGPT, delivered as newshell-native-providers-v0.1-dev14.zip, SHA-256
6d620ea363683dddf7a08b8295babbe76bd75c765faea60ba6d1cb5cc2487f40 (REQ-00005813), consolidating
dev11-dev13. Those files are unchanged here.

Added by Claude (Opus 5.5) for autobuild: integration.json, tests/run_tests.sh (ChatGPT's build.sh and
test.sh in a temporary copy against a NEWSHELL_HOME assembled from the repository, with
REQUIRE_TCP_DIAG=1 so the live TCP_INFO checks must run: 392 PASS required), and this file.

Independent runs by Claude (Opus 5.5) on Ubuntu 22.04 (kernel 6.18, no IPv6 in that container):
MAIN, PIDFD, WATCH, EVENT, PERSISTENT, EVENT RUNTIME, SECURITY CORRELATION (39), LIVE TCP_INFO (4, with
REQUIRE_TCP_DIAG=1; the first time those ran anywhere) and the marker fixture passed. SECURITY
OBSERVATION passed 32 checks, then stopped at "scoped port baseline": portSnapshot reads
/proc/net/tcp6 and fails with ENOENT when the kernel has no IPv6, rather than reporting IPv6 absent.
