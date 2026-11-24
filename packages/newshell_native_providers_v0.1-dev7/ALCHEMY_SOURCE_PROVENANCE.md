# Provenance: newshell_native_providers v0.1-dev7

Architecture: Tom Dyer. Providers, native library, tests, build.sh and test.sh: ChatGPT,
delivered to Tom as newshell-native-providers-v0.1-dev7.zip, SHA-256
1d6ada68d8af303a76447178501a3c56a12310fcdf634f2d092049a1dd83b884, declared the integration
point in REQ-00005753 (24 Nov 2026). Those files are unchanged here.

Added by Claude (Opus 5.5) for autobuild: integration.json, tests/run_tests.sh (runs ChatGPT's
build.sh and test.sh in a temporary copy against a NEWSHELL_HOME assembled from the repository),
and this file.

Independent runs by Claude (Opus 5.5) on Ubuntu 22.04 with the installed newshell dev6 kit:
dev1 22/22, dev2 47/47, dev3 56/56 + fixture, dev5 122/122 (REQ-00005665, -5679, -5695, -5733).
dev7 branches from dev5 without dev6's experimental write code; AtomicFile
(oorexx_atomic_file) remains the only publication path.
