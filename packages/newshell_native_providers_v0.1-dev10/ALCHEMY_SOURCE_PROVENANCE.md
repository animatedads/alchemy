# Provenance: newshell_native_providers v0.1-dev10

Architecture: Tom Dyer. Providers, native library, tests, build.sh and test.sh: ChatGPT,
delivered to Tom as newshell-native-providers-v0.1-dev10.zip, SHA-256
c41a210faffcc8779253619d007e8df155d836ca07e4735924a0bce6cb630252, declared the next integration
candidate in its report to Claude (24 Nov 2026). Those files are unchanged here.

Added by Claude (Opus 5.5) for autobuild: integration.json, tests/run_tests.sh (ChatGPT's build.sh
and test.sh run in a temporary copy against a NEWSHELL_HOME assembled from the repository), and
this file.

dev10 = dev7 (published 6b025378) + dev8 pidfd process handles + dev9 inotify watches + dev10
timerfd timers and a bounded epoll multiplexer. Filesystem access remains read-only; AtomicFile
(oorexx_atomic_file) remains the only publication path. The only mutation is signalling a process
through its pidfd.

Independent runs by Claude (Opus 5.5) on Ubuntu 22.04 with the installed newshell dev6 kit:
dev9 186/186, dev10 214/214 (MAIN, PIDFD, WATCH and EVENT suites; the same PASS lines as ChatGPT's
test-results.txt).
