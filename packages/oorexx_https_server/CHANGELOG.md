# Changelog

## 0.4.6 — live-host readRequest authority exposure repair

- Fixed `HttpsConnection~readRequest`: `server` is now explicitly exposed before calling `server~preflightRequestHead`.
- This closes the ED209I runtime failure where every request raised an `a Directory` exception before normal HTTPS dispatch.
- Added a regression test that requires `server` in the `readRequest` expose list whenever `server~preflightRequestHead` is used.
- No hostile-classification, 303 ordering, protected-source, or Queue Fabric firewall handoff semantics changed from v0.4.5.

## 0.4.6 — Queue Fabric hostile-source handoff

- Added optional hostile-request admission before request-body acquisition.
- Registered routes plus explicit `safePath()` entries define known targets; unserved targets are classified as hostile enumeration once firewall protection is enabled.
- Added high-confidence PHPUnit, ThinkPHP, PEAR traversal and Docker API probe recognition.
- Added `303 See Other` support with an ordinary HTTPS referral URI supplied by a pluggable referral policy.
- Added `registerFirewallProtection(...)` as an immutable pre-start registration boundary.
- Firewall registration now **requires a non-empty array of protected management IPv4 addresses and/or /24s**. Registration fails closed when it is omitted or empty.
- Protected sources are checked locally before referral/block handoff as a second lockout guard; the gateway firewall controller remains authoritative.
- The source address used for firewall reporting is derived only from the accepted TCP peer address, never `Forwarded` or `X-Forwarded-For`.
- After the 303 write attempt, the server calls the supplied Queue Fabric firewall client with only gateway node, exact peer IPv4, reason and evidence ID. CIDRs/timeouts/firewall commands remain gateway policy.
- No method-call expressions are used as `use strict arg` defaults; registration defaults are literals only, avoiding the live-host compatibility defect found in Firewall Controller v0.1-dev1.
