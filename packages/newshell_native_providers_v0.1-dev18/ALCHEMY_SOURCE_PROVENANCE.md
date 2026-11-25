# Provenance: newshell_native_providers v0.1-dev18

Architecture: Tom Dyer (switch kernel audit on at runtime, no reboot, no boot command
line change; 25 Nov 2026). Ordered by Claude (Opus 5.5) as REQ-00005869.

Providers, native library, runtime classes, bin/audit-switch.rex, tests, build.sh and
test.sh: ChatGPT, delivered as newshell-native-providers-v0.1-dev18.zip, SHA-256
a0d64e72b3ccc92ab8624f94016909787f637a1af07972938c953c83f291db5d (REQ-00005871).
Those files are unchanged here. Depends on packages/oorexx_logging_v0.8-candidate1.

Added by Claude (Opus 5.5) for autobuild: integration.json, tests/run_tests.sh
(ChatGPT's build.sh and test.sh in a temporary copy; REQUIRE_TCP_DIAG=1 by default;
REQUIRE_AUDIT_LIVE passed through, default 0; 501 PASS required) and this file.

Review by Claude (Opus 5.5) of the safety rules in native/audit_netlink.h and
src/AuditSwitch.cls:
- AUDIT_SET carries mask = AUDIT_STATUS_ENABLED only; values above 1 are refused before
  any message is built, so enabled = 2 (lock until reboot) cannot be sent.
- setEnabled reads status first and refuses with EPERM when audit is already locked;
  it reads back after the change and fails unless the value took.
- The pid field is never set: the tool never registers as the audit daemon. Failure
  mode, backlog limit and rate limit are never touched.
- The reader joins the READLOG multicast group only, rejects truncated datagrams and
  non-kernel senders.
- audit-switch.rex logs the request before any change and the result after, and makes
  no change if the request could not be logged or audit is locked.
- The live test restores the original enabled value on every exit path it controls
  (normal end, failed check, SIGINT/SIGTERM/SIGHUP); SIGKILL cannot be caught.

Independent run by Claude (Opus 5.5) on Ubuntu 22.04, ooRexx 5.3.0, in a container with no
IPv6, REQUIRE_NO_IPV6=1 and REQUIRE_TCP_DIAG=1: 506 PASS (dev17's 470 plus 14 wire and
22 audit netlink checks). The live audit test (REQUIRE_AUDIT_LIVE=1) was not run here:
switching kernel audit is for an approved MU, and cats2 is approved under rule R1.
