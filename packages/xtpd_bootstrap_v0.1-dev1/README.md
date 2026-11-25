# xtpd bootstrap role component v0.1-dev1 — partial grid item 1

Architecture: Tom Dyer. Coding/local qualification: ChatGPT.

Order REQ-00005885; grid rules R1–R5 and arbitrator.bootstrap/recovery read before development. This is a **source component for the single xtpd host**, not a competing network daemon, an installed service, or a qualified grid node. No keys, Auth, NSG, or estate nodes have been changed. The xtpd sphere describes a design, and the actual host executable/role exchange/LDAP role probe contracts were not available for executable integration in this environment.

## Implemented

- Strict, bounded local LDAP role record in the existing arbitrator canonical `ROLE|LDAP|main|spare|epoch|version|seed1,seed2|key1,key2` shape. Logical peer identifiers only (no carrier selection). Empty spare/seed list allowed. Positive canonical integer epoch/version, max 18 digits. Local file is canonical record, newline, signing key id, newline, 128-character MAC hex (no trailing newline).
- `XtpTestRoleVerifier`: existing ooRexx HMAC-SHA512 library with domain-separated bytes `XTP-ROLE-TEST/1:` + canonical record. Test key only. Shared-key MAC, **not** the real Ed25519 Auth or asymmetric signature. The verifier receives an independently provisioned test-key directory; the record contains key identifiers, never key material. Test verifier is not a production security boundary (holders of the secret could also sign). Key-list changes deliberately refused: R1 excludes key changes. Do not install test keys on an operational node without explicit authority.
- Offers verify trust and MAC before checking monotonic epoch/version and publishing. Only the existing AtomicFile service is the production write boundary; FULL/noFollow required, and the result must report publication, both fsyncs and durability. Any uncertain publication or missing required logging delivery quarantines the runtime. No local-file rollback defence against an attacker able to replace the entire trusted file with an older valid record. Protect the configuration and ancestor directories against untrusted writes; the Stream reader is not a hostile-path traversal guard.
- `catchUp` snapshots the initial file's main, spare and seeds; does not ask LDAP for the role addresses or expand the query set from an unverified offer. Accepts only newer records; matching verified current record confirms a source. A lower-version record is not confirmation. The single trusted host serializes startup/announcements; no independent CAS/lease or cross-process locking.
- `resolve` requires an explicit positive trusted probe of the precise peer, role, epoch and version; main is FRESH, spare is STALE, no response is UNAVAILABLE. Never autonomously promotes or changes DNS. `start` returns SOURCE, STATUS, PEER, READY (true only FRESH). This is not proof of actual network freshness until the real probe is implemented and tested.
- Boot load, update request/result, rejection, resolution and logging-delivery failures handled via real existing LogService/LogEvent objects. The caller provides the configured logger; no second logging implementation. A successful in-process logging receipt is not durable storage. Host must configure the authorised critical logging target and independent operational handler.

## xtpd host integration contract (not yet installed)

At first boot, R3 image installation must deploy the accepted existing ooRexx/XTP/AtomicFile/logging kits and protected local bootstrap record. No build tools on cats. The **one existing xtpd host** should instantiate the component once before service resolution, using the already configured logging service and approved test verifier if the separate test profile is authorised:

```rexx
options = .AtomicFileOptions~new
store = .XtpRoleFile~new(roleFile, .AtomicFile~new, options)
bootstrap = .XtpRoleBootstrap~new(store, verifier, logger)
status = bootstrap~start(roleExchange, ldapRoleProbe)
```

`roleExchange~fetchRole(logicalPeer)` must return exact signed envelope or `.nil` after bounded failure. Use protected XTP named-service sessions and existing route table, not raw IP service descriptors or a second listener. The received announcement hook calls `bootstrap~offer(bytes)`; no key, epoch or role change before verification. `ldapRoleProbe~confirms(peer, role, epoch, version)` must obtain an authenticated current response from that precise role holder, not merely a successful socket open, local file value or cached response. A trusted in-process provider interface is not proof of network identity. Actual protocol/hook, timeout and retry lifecycle must be coordinated with xtpd and the LDAP owner. Failure must not advertise MU_READY; controller may continue in degraded mode, but never report FRESH from the file alone.

Enable the existing xtpd systemd unit only after binding these components to its actual host lifecycle. Do not create a second xtpd service or alter SSH, firewall or Azure network settings. Item 1 is not done until an approved cats2 cold boot demonstrates the real service process, authenticated LDAP.main FRESH from the role file, and structured first-boot receipts without login. Repeat after rebuild (R5); keep SSH open (R2). No deployment has been attempted here.

## Qualification

`NEWSHELL_HOME=/path/to/newshell ./test.sh` with ooRexx 5.3.0 r13196 and existing dev6 kit LoggingCore/crypto. 34 PASS lines, SUITE PASSED. Actual file read and real LogEvent delivery; simulated peer fetch/probe and store replacement, including failure and reconstruction over same store. AtomicFile adapter contract checked against published AtomicFileResult/Options source; native publication not executed here. Initial test harness missed explicit RETURN and an ooRexx special RESULT variable collision; corrected and entire suite rerun. No real XTP session, LDAP probe, native AtomicFile publication, systemd boot, Jammy build or cats2 field test. No Git publication or new workstation brief. No claim item 1 complete. Self-score component implementation 7/10, field qualification 2/10.
