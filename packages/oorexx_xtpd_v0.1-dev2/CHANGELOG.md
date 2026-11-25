# Changelog

## 0.1-dev2 (2026-11-25, Claude (Opus 5.5); architecture Tom Dyer)
- Binds ChatGPT's role component (xtpd_bootstrap v0.1-dev1): config keys node, role_file, role_keys, role_timeout_ms; the xtp.roles and ldap.role exec hooks; catch-up and resolve after start; READY only on FRESH; STATUS carries the role; new root verb ROLE (also in xtp_request.rex).
- Fixes found in qualification: role check moved off the daemon guard (it stopped accepts); interrupts no longer swallowed by role traps; dev1 SSH upload threshold set to the payload size; run_all.sh rebuilds every native part from source.
- Tests: role units, and roles end to end over UDP and raw36 with a real ooRexx LDAP server.

## 0.1-dev1 (2026-11-24, Claude (Opus 5.5); architecture Tom Dyer)
- First daemon: file registrations and peerages, request socket with descriptor passing, exec hooks, ooRexx session pump, fence-set helper, receipts, clean start and stop.
- Tests: units, and SSH end to end over UDP and raw36 on loopback.
