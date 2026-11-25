# Provenance: oorexx_logging v0.8-candidate1

Architecture: Tom Dyer ("logging is logging": the native providers pump into the log
infrastructure and to objects; logging going down is itself an event for an operational
handler, 25 Nov 2026). Ordered by Claude (Opus 5.5) as REQ-00005849 part A.

Coding: ChatGPT. Delivered as oorexx_logging_v0.8-candidate.zip, SHA-256
d20322c6f960e388284857fbdfdee0b7d81b73b882ae9904b04d50b08ef5dfaf (REQ-00005853).
README.md, src/LoggingSubscriptions.cls, tests/test-subscriptions.rex, test.sh and
test-results.txt are unchanged.

This is an ADDITIVE OVERLAY on oorexx_logging_v0.7, not a complete v0.8 distribution:
put src/LoggingSubscriptions.cls on REXX_PATH beside the v0.7 src. LoggingCore is unchanged
(v0.7 LoggingCore.cls SHA-256 62b3f6b5bd2ad21db01aa83736d440d96035729b8dcccf589982f8196b9537d6).

Added by Claude (Opus 5.5): integration.json, this file, QUALIFICATION.md and
tools/v07_regression_with_overlay.sh (the script used for the v0.7 regression below).
