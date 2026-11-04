# XTP per-service protection (dev32 sessions, dev33 messages and streams, dev34 multipath, dev36 evidence)

**Architecture:** Tom Dyer (decision D-07, 28 October 2026). **Coding:** Claude (Opus 5.5). **Written by:** Claude (Opus 5.5), 28 October 2026; dev33 sections the same day.

## The decision this implements

From `design/rexxos/ARCHITECT_DECISIONS.md`, D-07:

- **The split.** libxtp carries the protection mechanism. Keys, identities and policy come from outside it.
- **Key sources.** LDAP first; a key file is the fallback when LDAP is unavailable.
- **Two options:** authentication and encryption.
- **Per service.** XTP links are per named service, so each named service has its own protection profile and its own keys.
- **The same strategy for X.25.** See the last section.

## Model

| Thing | Where it lives | Notes |
| --- | --- | --- |
| Profile of a service: none, authenticate or encrypt | The key set's usage in the Identity Directory (`XTP_AUTHENTICATE`, `XTP_ENCRYPT`), or the key file's protection column | None until the service first has keys. From then on it is **sticky**: expiry, revocation or a refresh that no longer lists the keys leaves the profile in place, so opens fail instead of falling back to clear. Only `forget_profile` (an operator action) lowers it; `require` sets one before any keys exist |
| Long-term key | A key generation: a 32-byte secret, a 64-bit key ID, a suite, a validity window, a state | ACTIVE keys open and accept. RETIRING keys only accept, which is how rotation works |
| Secret material | Secret Broker, reached through the generation's secret reference | Never travels over LDAP |
| Keys in use | `KeyTable::global()` in libxtp | Filled by `rexx/XtpServiceKeys.cls`, by a C++ caller through `install`, or from a key file through `load_file` |
| Per-context keys | Derived for each session, never stored | See "Wire" |

## Where keys come from (`rexx/XtpServiceKeys.cls`)

```rexx
ldap    = .XtpLdapKeySource~new(sockets, 'xtp.keys.ldap', bindDn, bindSecretRef, baseDn, broker)
file    = .XtpFileKeySource~new('/etc/xtp/service.keys')
keys    = .XtpServiceKeys~new(.array~of(ldap, file))
outcome = keys~refresh        -- SOURCE ('ldap' or 'file'), COUNT, ERRORS, WARNINGS
```

- **Order.** Sources are tried in order, and the first that works wins. A source that raises an error has failed, and the next is tried.
- **One step.** A source replaces all of its keys at once (`KeyTable::replace_source`, `xtpNativeKeyReplaceSource`). Everything is checked first; a bad key refuses the whole set and changes nothing. There is no moment at which a service has lost its old keys but not received the new ones.
- **When LDAP works,** keys loaded from a file are removed, because the file is only a fallback.
- **When LDAP fails,** keys already fetched from it stay until they expire, and the file is loaded as well.
- **What "works" means for LDAP.** The bind and the three searches (principals, key sets, generations) succeed, and at least one usable XTP key is found. Zero keys counts as a failure, because it usually means the bind DN cannot read the key sets or the base DN is wrong.
- **Each entry is checked on its own (dev33).** An entry that fails a check is skipped and reported in WARNINGS. It never stops other services' keys from being refreshed; in dev32 one bad entry blocked every update, revocations included (second review, F2). A service whose set is broken loses its LDAP keys, and its sticky profile then makes its opens fail: it fails closed, alone. The checks:
  - a key set must be owned by `service:<name>`, where `<name>` is a valid XTP service name: no spaces or control characters, no `[` or `]`, at most one colon, not an IPv4 literal (second review, F1: a name carrying a newline could smuggle a second key line);
  - the owner must be a principal in the directory, the set must sit under that principal's entry, and no other set may have its entity ID (two sets with one ID are both skipped);
  - a usable generation must sit under its key set's entry, and have a 16-hex-digit key ID, readable dates, and a secret reference that starts with `secret://xtp/<service>/` (the prefix is an argument);
  - Secret Broker must resolve the secret to 64 hex digits.

  A generation placed outside its set is ignored, and not counted against the set it names, so nobody can block another service's keys by planting entries. The placement rules mean a principal that may write only its own subtree cannot attach a key to another service. The prefix rule means the directory cannot make this process fetch an unrelated secret with its own broker authority. `parse_key_line` also checks every service name and principal, so the C++ side refuses a crafted name whatever source it comes from.
- **Refreshing.** Call `refresh` on a timer, or when LDAP reports a change. LDAP sync and persist are available in the LDAP package; they are not wired in yet.

### Identity Directory mapping (`rexx/XtpLdapKeySource.cls`)

It uses the estate's own `LdapWireClient` over SocketSelector, with a simple bind whose secret comes from Secret Broker.

| Directory entry | XTP meaning |
| --- | --- |
| Principal `service:<name>` | The named service |
| Key set owned by `service:<name>`, usage `XTP_AUTHENTICATE` or `XTP_ENCRYPT` | The service's profile |
| Key generation, algorithm `AES256GCM` or `CHACHA20POLY1305` | The suite |
| The generation's public material | The 16-hex-digit XTP key ID |
| The generation's secret reference | 64 hex digits (32 bytes), resolved through Secret Broker and retired straight after |
| Generation state ACTIVE or RETIRING; notBefore and notAfter | Used as described above. Other states are ignored |

### Client keys (gateway mode B, dev35)

A gateway that lets a foreign client reach a service gives that client its own key, for a limited time, so it never holds the service's key.

- **In the directory:** a client is a principal `service:<name>/client:<id>`. Its entry must sit under the service principal's entry, so only whoever administers the service can create clients. The client's key set (usage `XTP_AUTHENTICATE` or `XTP_ENCRYPT`) sits under the client, and its generations under the set, as for a service. The lease is the generation's validity window and state: the gateway revokes a client by retiring or revoking the generation, or lets `notAfter` pass.
- **Installed as:** keys of the service, held for principal `<id>`.
- **Used by:** only an opener that names that principal (`SessionOptions::key_principal`, `SendOptions::key_principal`; in ooRexx `XtpSession~open`'s fifth argument, or the session socket's `XTP_KEY_PRINCIPAL`). Since dev35 the choice is exact both ways: an opener naming no principal uses only the service's own keys, and one naming a principal uses only that principal's.
- **Seen by the listener:** `Session::key_principal()` and `ReceiveResult::key_principal` say which client opened, so the gateway can apply its policy and write its receipt.
- **Checks:** a client ID is 1 to 128 characters, with no space, control character or slash. A client whose principal is not under its service's principal is skipped and reported. A service name may no longer contain a slash in an LDAP key set's owner.

Gateway mode B stays disabled in the gateway until its gates are qualified (ChatGPT, REQ-00001287); this only provides the keys.

### Key file (the fallback)

One key per line, separated by spaces or tabs:

```text
# service  key_id(16 hex)  protection  suite  secret(64 hex)  [principal|-  not_before_ms  not_after_ms  active|retiring]
svc.ldap   00000000000a11c1  encrypt  aes256gcm  <64 hex digits>
```

- `load_file` opens the path without following a symbolic link, then checks the open file: it must be a regular file, owned by the process's user, with no group or other permissions (mode 600 or stricter), and at most 4 MB.
- Every field is checked strictly: exact hex lengths and hex digits only, protection `authenticate` or `encrypt`, a non-zero key ID, dates as digits, state `active` or `retiring`. The same parser checks keys from LDAP and from `xtpNativeKeyInstall`.
- A bad line is reported with its line number, and the keys already loaded stay in place.

## Wire (3.4 profile, sessions)

**Why one primitive for both options.** Authentication uses the same AEAD as encryption, with nothing to encrypt; that is GMAC or Poly1305 over the whole packet. The proposal had suggested HMAC-SHA256 for authentication alone. Since both options are now wanted, one primitive means one tail format, one key schedule, one verification path and one set of tests. The tag is 128 bits in both cases, and AES-GCM runs on the AES instructions this host has.

**Descriptor flags.** In the named-service descriptor, byte 4 (flags) adds `0x02` AUTHENTICATED and `0x04` ENCRYPTED to dev31's `0x01` INTERACTIVE.

**Open.** The initiator's FIRST carries an open block after the descriptor, then a tail:

```text
"XSEC" | version 1 | suite | protection | 0 | key id (8) | initiator nonce (16) | Unix ms (8) | tail
```

The tail is under the open key:

```text
HKDF-SHA256(secret, salt = initiator nonce, info = "XTP-OPEN-1" ‖ service ‖ KEY)
```

Before any cryptography, protected opens are rate limited: 200 a second (burst 400) from each sending address, and 2,000 a second in total, by default (`open_rate_per_sec`, `open_burst`, `open_global_rate_per_sec`). Opens over the limit are dropped unanswered.

The responder drops the open, and never answers it, unless all of these hold:
- it has a valid key with that ID for this service;
- the tag verifies;
- the timestamp is within ±30 s of its clock (clocks need NTP);
- the nonce has not been seen.

The nonce is remembered for 60 s, but only once the open is admitted (service admitted, profile met, room for the context). The cache is a hash set with an expiry queue, so each open costs the same however full it is. It holds at most 65,536 nonces, and at most 16,384 for any one key ID, so one key holder cannot fill it for everyone.

**Key confirmation.** An open that verifies is not yet proof that its sender holds the key: it could be a copy, replayed within 30 s to another listener with the same service key, or to this one after a restart. So a protected context is **unconfirmed** until a packet arrives that verifies under the opener's new context key. Only a key holder can send one; the opener sends a CNTL as soon as it has the accept.
- An unconfirmed context is not offered to `accept()`.
- It resends its accept at most 8 times, and is dropped silently after 10 s.
- A repeated open is believed only while the context is unconfirmed, only if it is byte-identical to the open that verified, and it never counts as a sign of life. Once the context is confirmed, repeated opens are ignored.

**Accept.** The responder's FIRST carries this, then a tail under the new context key:

```text
"XSEC" | 1 | suite | protection | 0 | responder nonce (16)
```

**Context keys.** The context keys are:

```text
HKDF-SHA256(secret, salt = both nonces, info = "XTP-CTX-1" ‖ service ‖ KEY ‖ protection ‖ suite)
```

They are 64 bytes, one 32-byte key per direction. The suite and the protection are inside both the derivation and the authenticated data, so neither can be downgraded.

**Every later packet** (DATA, CNTL, abort or END, refusal DIAG) ends its segment with 24 bytes:
- an 8-byte packet counter;
- a 16-byte AEAD tag.

The tag covers:
- the header;
- the clear part of the segment (in encrypt mode, the DATA bytes are ciphertext instead);
- the trailer's DSEQ, pad, flags and TTL;
- the counter.

The nonce is the direction byte, three zero bytes, and the counter. Each direction has its own key, and every send gets a new counter, retransmissions included. A 1,024-packet anti-replay window rejects repeats. XTP checksums are recomputed after sealing, so the packet stays a valid 3.4 packet.

**Failures.**
- A packet that fails is dropped and counted in `SessionStats::auth_failures` or `replays_rejected`. It is never answered.
- A protected opener believes a DIAG only if it carries a tail under its open key. An unauthenticated refusal is ignored, though it is named in the timeout error.

## Wire (3.4 profile, one-way messages and streams, dev33)

A protected service's messages go as FIRST+DATA streams, even a message that fits one packet. There is no handshake: a one-way message has no round trip before its data.

- **The FIRST** carries, after the named-service descriptor (with the AUTHENTICATED and ENCRYPTED flags), an 8-byte guard and then the same 40-byte open block as a session: `"XSEC"`, version 1, suite, protection, 0, key ID, the sender's 16-byte nonce, and Unix ms. The first data follows.
- **The guard** (`"XWF1"`, 1, 0xFF, 0, 0) is what every older listener reads as a wire-filter envelope with an unknown filter, so it refuses the message as MALFORMED. Without it, the dev33 interop check showed a dev32 listener delivering the open block, ciphertext and tail to its application as if they were the message. The sender then fails, and says the receiver may be older than dev33 (`tests/test_interop_protected.sh`).
- **Keys:** `HKDF-SHA256(secret, salt = sender nonce, info = "XTP-MSG-1" ‖ service ‖ KEY ‖ protection ‖ suite)`, 64 bytes: sender to receiver, then receiver to sender. The label keeps message keys apart from session keys.
- **Every packet** (FIRST, DATA, the sender's status requests, the receiver's CNTLs and refusals) carries the 24-byte tail, with a fresh counter for every send, retransmissions included. In encrypt mode the data is encrypted; the descriptor and open block stay clear and are authenticated.
- **The receiver** checks the FIRST before believing anything: the open rate limit (per host), a valid key with that ID for the service, the tag, the clock (±30 s), and that the nonce is new. Then the service's profile and admission; a refusal from here on is sealed. The nonce is remembered for 60 s, as for sessions. It verifies, decrypts and strips the tail and open block, and hands the dev32 stream code a plain packet; its replies are sealed on the way out.
- **The sender** believes only CNTLs and refusals that verify. A forged close-acknowledgement (the dev28 failure) is dropped and counted in `SendResult::auth_failures`. An unauthenticated refusal is ignored and named in the error if the send then fails.
- **What the receiver reports:** `ReceiveResult::protection`, `key_id` and `key_principal`; in ooRexx, `XtpNamedAcceptedSocket~protection`, `keyId` and `keyPrincipal`, or `xtpNativeListenerLastProtection`.
- **Profiles are sticky and minimums, as for sessions.** `SendOptions::protection` is a minimum, and a service whose keys have gone refuses to send.
- **Key lifetime (dev34):** a message context ends at both ends when its key is revoked, expires or leaves the table: the receiver checks at most every 250 ms (dev35), the sender once a second, and stops mid-stream with an error.
- **Never a message:** a FIRST or DATA with the return bit set, and a FIRST flagged interactive (a session open), are dropped by a message listener (dev34).
- **Listener policy:** a clear or weaker message of a service with a profile gets DIAG 17 AUTH_REQUIRED and is not delivered. `ListenOptions::require_protection` also refuses clear messages of services with no profile.

**Multipath (dev34).** XMP1 sends each chunk with `send_message`, so a multipath transfer to a service with a profile is protected chunk by chunk. The multipath listener now keys a transfer by its ID *and* the service, protection and key its chunks arrived under, so a clear chunk that claims a protected transfer's ID starts a different transfer and is never mixed in. It reports `MultipathReceiveResult::service_name`, `protection` and `key_id` (in ooRexx, `xtpNativeMultipathLastProtection`, and the accepted socket's `protection`). A malformed chunk, a chunk count beyond 2^20 or the transfer size, or a transfer larger than `max_logical_bytes` is dropped and logged; in dev33 and earlier one such chunk ended `receive()`, and a chunk count of 2^32-1 made it try to allocate that many slots. At most 1,024 transfers are assembled at once. In ooRexx, `XtpMultipathSocket` takes a named service as its fifth argument.

**The limit of having no handshake.** Within the 30 s clock window, a captured protected message can be replayed once to *another* listener that holds the same service key: a pool node, or the same listener after a restart. Each listener delivers it at most once (its nonce cache), and nobody without the key can make or change one, but a genuine message can arrive twice across a pool. Sessions do not have this limit, because the opener must prove the key before `accept()`. A service that needs exactly-once delivery across a pool should use sessions, or make its messages idempotent.

## Listener policy (sessions)

| Case | Result |
| --- | --- |
| Service has keys, open is unprotected | DIAG 17 AUTH_REQUIRED, unauthenticated |
| Service has keys, open is protected but weaker than the profile | DIAG 17 AUTH_REQUIRED, authenticated under the open key |
| Service's keys expired or revoked, but its profile is sticky | Protected opens are dropped (no valid key); unprotected opens get DIAG 17 AUTH_REQUIRED |
| `require_protection` set, service has no keys, open is unprotected | DIAG 17 AUTH_REQUIRED |
| Service has no keys and no profile, open is unprotected, no `require_protection` | Accepted unprotected, as in dev31 |
| Any service has a profile, and unprotected contexts already hold half the table or half the backlog | DIAG 19 QUOTA_EXCEEDED (dev33, F4) |
| One host already holds an eighth of the table (at least 4) in unconfirmed protected contexts | Dropped (dev33) |

**Every open is rate limited (dev33).** In dev32 only protected opens were, and per address and port. Now every open, clear or protected, is limited per sending host (not port; F5) and in total, before anything else is done with it. A listener that hosts a protected service should also set `allowed_services`.
The opener uses the stronger of the service's profile and what it asks for; asking for `none` never lowers the profile. If there is no active key, `open_session` refuses before sending anything.

**Key lifetime.** About once a second each endpoint checks that the key of every protected context is still in the key table and valid. A context whose key was revoked, has expired or has left the table is closed at that end, and the other end is told. A RETIRING key is still valid, so rotation does not end sessions: move the old key to RETIRING, wait for its sessions to finish, then remove it. Since dev33 the same check also closes a context weaker than its service's profile now, such as a clear session opened before the service had keys (F3).

**Refusals under the open key** use a random 64-bit counter (dev33, Q5). In dev32 they always used counter 0, so two refusals of one open reused an AEAD nonce.

## Review, 28 October 2026

An independent review (Claude (Opus 5.5), given only the code locations) ran probes against the first dev32 build. Every finding is fixed and has a test.

| Finding | Fix | Test |
| --- | --- | --- |
| H1. A service's protection fell to none when its keys expired | Sticky profiles; opens fail closed | P14; ooRexx step 4 |
| H2. A refresh cleared keys before installing new ones, and a bad key left the table half-cleared | `replace_source`: checked first, swapped in one step | P15 |
| H3. LDAP "worked" with zero or partial results and then removed the file keys; a raised error skipped the fallback | Zero keys or any bad entry is a failure; a raising source is a failed source | ooRexx steps 2b, 2c, 2d |
| M1. Each open scanned the whole nonce cache; one key holder could stall the endpoint | Rate limit before cryptography; O(1) nonce cache, filled only after admission, with a per-key quota | P18 |
| M2. A replayed open reached `accept()` at another listener holding the key | Key confirmation before `accept()` | P16 |
| M3. A copy of the open was believed without its tag and kept a dead context alive | Byte-identical, unconfirmed contexts only, never a sign of life, bounded resends | P17 |
| ML1. The LDAP source trusted the directory's structure | Placement, ownership, duplicate and secret-prefix checks | ooRexx step 2c (prefix); placement checks have no fixture yet |
| ML2. The key-file check could be bypassed by a symbolic link or another user's file | `O_NOFOLLOW`, then `fstat`: regular file, owner, mode | P20 |
| L1. Secret copies were left in memory | `~ServiceKey` wipes; parser and native strings wiped | Inspection |
| L2. `xtpNativeKeyInstall` accepted non-hex secrets | The strict key-line parser | P20 |
| L3. Asking for `none` bypassed the profile | The option is a minimum | P14 |
| L4. Revoking a key did not end its contexts | A once-a-second key check per endpoint | P19 |

## Second review, 28 October 2026 (fixed in dev33)

A second independent review of the committed dev32 (21aa0a1f) confirmed nine findings with probes. Its report was cut off after the fifth; the other four are taken from its probe file (Q4 to Q7). All are fixed in dev33.

| Finding | Fix | Test |
| --- | --- | --- |
| F1 (high). A tenant could plant a key for another service: a principal ID carrying a newline smuggled a second key line | Service names checked in the LDAP source and in `parse_key_line`; principals too | ooRexx hostile `inject`; P27 |
| F2 (high). One bad entry anywhere stopped every LDAP update, revocations included | Problems are per entry; misplaced entries are ignored, not charged to the set they name | ooRexx hostile `tenant`, `placement` |
| F3. A clear session survived its service getting a profile | The key check closes contexts weaker than the profile | P22 |
| F4. Clear opens of made-up names filled the table, with no rate limit | Every open is rate limited; unprotected contexts get at most half the table and backlog once any profile exists | P23 |
| F5. The open limit was per address and port | Per host; also at most an eighth of the table in unconfirmed contexts per host | P24 |
| Q4. Unconfirmed contexts with their resends spent woke the endpoint every 1 ms | Not scheduled once resends are spent | P25 |
| Q5. Two refusals of one open reused an AEAD nonce | Random refusal counter | P26 |
| Q6. Copies of secret hex were left in freed heap by the parser | Fields parsed as views of the caller's line; one wiped line buffer | Inspection |
| Q7. `replace_source` was O(n²) under the table lock | Hash sets: 32,000 keys replaced twice in under 50 ms | P27 |

A dev33 test also found a dev32 defect: protected sessions at the full L2 MTU failed, because the tail did not fit. The segment now leaves room for it (P21).

## Third review, 29 October 2026 (dev33 code, fixed in dev34)

A third independent agent checked dev33's messages and streams against this document, with its own probes.

| Finding | Fix | Test |
| --- | --- | --- |
| H1 (high). A clear FIRST or DATA with the return bit set skipped the checks, because the parser masks that bit: it was delivered to a protected service, and could replace a DATA of an authenticated stream | The listener drops FIRST and DATA with the return bit | M14 |
| H2 (high). A clear FIRST flagged INTERACTIVE (and claiming protection) was delivered as a message | A message listener drops interactive FIRSTs, protected or not | M15 |
| M1. Every listener accepting a FIRST derives the same receiver key and counted from 1, so a pool node, a restart or a replay reused AEAD nonces | The receiver's counter starts at a random 63-bit value | M16 |
| M2. An empty protected message was never sent | One FIRST, even when empty | M17 |
| L1. Eviction could drop a context in mid-stream; the documentation said it cost only a retransmission | Finished contexts are evicted first; the documentation corrected | M19 |
| L2. Small segment sizes overran the budget | Refused with the minimum stated | M18 |
| L3. A revoked key did not end a message context | Both ends check the key at most once a second | M20 |
| L4. A principal or key-set ID appearing twice in a directory without unique IDs could block or plant a key | Duplicate principal IDs are not trusted; duplicate set IDs count only among well-placed sets | Inspection: the estate's Identity Directory refuses duplicate IDs, so no fixture can build them |

## Fourth review, 29 October 2026 (dev34 code, fixed in dev35)

A fourth independent agent checked dev34's changes against this document, and ran mutations of the tests to see whether they would catch a removed fix.

| Finding | Fix | Test |
| --- | --- | --- |
| 1 (high). A sender with no key could make the multipath listener reserve 24 MB per transfer (2^20 chunk slots allocated up front), about 24 GB over 1,024 transfers | Slots are allocated only as chunks arrive; all unfinished transfers together hold at most twice `max_logical_bytes`; at most 64 unfinished transfers per host | M13: 40 transfers claiming 2^20 chunks grew memory by 20 KB (958 MB with eager slots, by mutation) |
| 2. M13 did not test the bound it claimed, and could hang | Each case under its own transfer ID; a watchdog ends a stuck receive | M13, checked by mutation |
| 3. M20 did not test the receiver half of revocation | The receiver checks every 250 ms, and the test counts the contexts it forgets | M20, checked by mutation |
| 4. Forgetting a context left stale entries in the listener's order lists | `forget_context` removes the ID from every order list | Inspection |
| 5. Finished multipath transfers stayed in the order list for ever | Removed on completion | Inspection |
| 6. A tenant could still block a service through duplicate IDs (planting was already prevented) | Key sets are taken by DN, not by ID; a generation belongs to the set it sits directly under; `serviceBaseDn` anchors service principals | ooRexx hostile `anchor`; duplicates themselves cannot be built in the estate's directory |
| 7. A key error marked every route to the peer DOWN | Key and protection refusals are a `ProtectionError`, which neither fails over nor marks path health | Inspection |

The mutation runs also showed M14 had not been setting the return bit on its DATA case (`payload_packet` masks it); M14 now covers FIRST and DATA, and fails by mutation without the fix.

**Recommended for production:** give `XtpLdapKeySource` a `serviceBaseDn` (the entry whose direct children are the service principals), so a tenant that writes only its own subtree cannot create a service principal. Without it, a tenant could claim a service name that has no principal in the directory.

## Protection evidence (dev36)

Written by Claude (Opus 5.5), 29 October 2026, for ChatGPT's REQ-00001733.

A program that admits a route on protection grounds, such as API Client before it runs TLS over an XTP stream, needs to know what protection the route has. It must not take that from its own request options. dev36 gives it two answers, both read from libxtp at the moment of the call, and neither carrying a secret.

**Before the open: route evidence.** `.XtpSocketBackend~routeEvidence(address)` (the same as `.XtpSessionSocket~routeEvidence(address)`). The address's metadata asks the question:
- `XTP_SERVICE` names the service;
- `XTP_KEY_PRINCIPAL` (optional) names a client;
- `XTP_PROTECTION` (optional) is a floor.

libxtp answers from its route table and key table what an open would get now. The floor can raise the answer, never lower it below the service's profile. From C-level callers, `.XtpSession~serviceEvidence(peer, service, principal, floor)` gives the same.

**After the open: session evidence.** `socket~evidence` on an `XtpSessionSocket` (or `session~evidence` on an `XtpSession`), on either end. It records what the two ends agreed when the session opened, and the key's state now.

Both return a directory. A value that does not apply is `-`. Values are given exactly, never rewritten. Service names and principals can contain `=` but never a blank, so split each word of LINE at its first `=`.

| Index | route | session | Meaning |
|---|---|---|---|
| SCHEMA | yes | yes | `xtp.protection.evidence/1` |
| BOUND | `route` | `session` | `session` is bound to an open, confirmed session; `route` is a prediction |
| MODE | yes | | `session` if the address selects an `XtpSessionSocket` (`XTP_MODE=session`), `message` otherwise; only session sockets have `evidence` |
| ROLE | | yes | `opener` or `acceptor` |
| ROUTE, LAYER, CARRIER, DESTINATION | yes | | the route-table entry the peer resolves to now; `-` and OPENABLE 0 if none |
| PEER | | yes | the peer's carrier address |
| SERVICE | yes | yes | the named service (session: as agreed on the wire) |
| PROFILE | yes | yes | the protection the service requires now (key table, sticky) |
| PROTECTION | yes | yes | route: what an open would use; session: what this session uses |
| OPENABLE, REASON | yes | | 1, or 0 with `no_route` (checked first, as the open does), `no_active_key`, `no_active_key_for_principal`, or `key_changed` (the key changed while the evidence was read) |
| OPEN | | yes | 1 while the session is open |
| SUITE | | yes | the AEAD in use |
| KEYID, KEYPRINCIPAL | yes | yes | the key (16 hex digits) and the principal it is held for |
| KEYSUITE, KEYSOURCE, KEYNOTBEFOREMS, KEYNOTAFTERMS | yes | yes | from the key table now. KEYSOURCE is `ldap` (XtpLdapKeySource), `file` (the key file) or `api` (any program call, `xtpNativeKeyInstall`); no other name is accepted |
| KEYSTATE | yes | yes | `active`, `retiring` (accepted, never used to open), `notyet` (not_before ahead), `expired`, `absent` (revoked or gone), or `replaced` (session only: a different secret now holds this key id). Only `active` and `retiring` keep a session open |
| ATMS | yes | yes | when it was read (Unix ms) |
| LINE | yes | yes | all of the above as one line of `name=value` words, for a receipt |

After `close` or `abort`, `evidence` returns the record read as the session was released, with OPEN 0 and that moment's ATMS.

**What session evidence proves.** A protected session exists only after key confirmation (see "Wire (3.4 profile, sessions)"). The peer therefore holds the secret of KEYID, and every byte of the session is authenticated, or encrypted, under keys derived from it. On the opener, SERVICE, PROTECTION, KEYID and KEYPRINCIPAL are taken from its own key table, not from anything the peer said. On the acceptor, the peer chose SERVICE, PROTECTION and the key (so KEYID, KEYPRINCIPAL and SUITE): any key, active or retiring, that the listener's own table holds for that service, at or above the service's profile. To admit only a particular client there, check KEYPRINCIPAL. PROFILE is the key table's; a listener's `XTP_REQUIRE_PROTECTION` floor is not shown in it.

**What it does not prove.**
- **Which host the peer is.** Any holder of the service's key can be the peer. To tell clients apart, give each client its own key (see "Client keys").
- **Anything, in route evidence, about the open to come.** It is a prediction: the open resolves the route and chooses the key again. Admit on route evidence, then check session evidence before sending anything.
- **Anything to another process or node.** The evidence is not signed. It is a local record from libxtp to its caller in the same process. Do not accept it from another component; get it by calling these methods yourself.
- **Anything against code in your own process.** KEYSOURCE says which loader installed a key. Program calls are always `api`, but any code in the process can call the loader routines, just as it can install keys for any service. Evidence protects a caller from its own request options and from the network, not from code it already runs.

**A changed secret ends its contexts.** Each key in the table has a serial. Installing the same id, service and secret again keeps the serial; any other secret under that id gets a new one. Sessions and message contexts check the serial with their key, so a reload that changes a key's secret but keeps its id closes them within about a second, as a revocation does (M21). Their evidence shows `KEYSTATE=replaced` at once.

**Why not in the address's metadata.** Metadata is written by whoever builds the address, so nothing in it can be authoritative. The address asks the question; libxtp answers it.

**A recipe for admission** (API Client, Wire runtime):
1. Before acquiring, call `ev = .XtpSocketBackend~routeEvidence(address)`. Admit only if `ev['OPENABLE'] = 1`, `ev['PROTECTION']` meets your floor, and `ev['KEYSOURCE']` is one your policy accepts. Under D-07, that is `ldap`, or `file` when LDAP is unavailable; never `api` in production.
2. Acquire the stream with `SocketProvider~streamSender`.
3. Before the first byte of TLS, call `s = stream~endpoint~evidence`. Require all of these:
   - `s['BOUND'] = 'session'` and `s['OPEN'] = 1`;
   - `s['SERVICE']` is the service you meant;
   - `s['PROTECTION']` meets your floor;
   - `s['KEYSTATE']` is `active` or `retiring`;
   - and, if the peer must be a particular client, `s['KEYPRINCIPAL']` is that client.
4. Put `ev['LINE']` and `s['LINE']` in your receipt.

A revoked key shows as `KEYSTATE=absent` at once, and libxtp closes the session within about a second.

Tested by `tests/test_xtp_protection_evidence_rexx.sh` (36 checks, two processes, four sessions), M21, and the LDAP test (`KEYSOURCE=ldap`).

**Review of dev36, before commit.** A separate agent checked the code against this section, and ran its own probes and mutations. Every finding is fixed:

| # | Finding | Fix | Test |
|---|---|---|---|
| 1 | KEYSOURCE was a label any caller could set | program calls are always `api`; the source names are a fixed vocabulary; the limit is stated above | `raises` checks |
| 2 | blanks and `=` were rewritten to `_`, so `svc.a=b` and `svc.a_b` gave the same evidence | values are given exactly; a blank is an error | look-alike check |
| 3 | a new secret under the same key id was not seen: the session ran on, KEYSTATE `active` | key serials; contexts end; KEYSTATE `replaced` | M21; step 12 |
| 4 | the test missed regressions in KEYSTATE, PROFILE and the floor | retiring, not yet valid, expired, floor over authenticate, session above its profile | mutation: each now fails |
| 5 | evidence after close raised an error | the record at release, OPEN 0 | step 16 |
| 6, 7 | acceptor: the peer's choices and the listener floor were understated | described above | |
| 8 | no route and no key gave `no_active_key` | `no_route` first | step 7 |
| 9 | a revoke between choosing and reading a key could give `openable=1` with a bad key | `key_changed` | |
| 10 | route evidence did not say whether the address gets a session socket | MODE | step 2 |
| 11 | `invalid` mixed revoked, expired and not yet valid | separate states | steps 13 to 15 |

## Evidence

- `make test-message-security`: M1 to M20 (messages, streams and multipath).
- `make test-security`: P1 to P28 (sessions; P28 client keys).
- `tests/test_xtp_service_keys_rexx.sh`: the ooRexx path, from a real LDAP server (the estate's own `LdapWireServer`, with the Identity Directory and Secret Broker) to an encrypted session, then the key-file fallback, then a wrong secret being refused.
- `tests/test_xtp_ldap_hostile_rexx.sh`: crafted names, misplaced generations and a broken tenant set, against a real LDAP server.
- `tests/test_xtp_message_keys_rexx.sh`: a protected message between two ooRexx processes.
- `tests/test_xtp_protection_evidence_rexx.sh`: route and session evidence (dev36).

`VALIDATION_DEV32.txt` and `VALIDATION_DEV33.txt` have the figures.

## Not yet

- **Replays across a pool** of protected one-way messages, within 30 s: see "The limit of having no handshake".
- **Multicast** carries no named service, so no profile applies to it; protecting it needs group keys, which is a separate design.
- **Message contexts** a listener remembers are bounded (`protected_contexts`, 4,096). When full, the oldest context that is not in the middle of a stream is forgotten. Only if every one is in mid-stream does the oldest stream lose its context; that transfer then fails at its sender (its resent FIRST is a replay by then), and is never delivered wrongly. (dev33's documentation said this cost a retransmission; the third review showed it cost the transfer.)
- **Push updates.** LDAP sync and persist are not wired in; `refresh` is called by the owner.
- **Clock dependency.** An open more than 30 s from the responder's clock is dropped.
- **Flooding.** Every open is rate limited per host before any cryptography. A flood from many forged addresses can still use up the total open rate, which delays new opens, not established sessions. Packets for an established context that fail verification cost one AEAD check each, about 1 to 2 µs, and are never answered.
- **Rekeying.** A context keeps its keys until it ends or its long-term key goes. The 64-bit counter cannot run out in practice.
- **Secrets in ooRexx memory.** The C++ side wipes every copy of a secret it makes. ooRexx strings cannot be wiped: the key sources drop their references straight after installing, and the interpreter frees them later.

## X.25: the same strategy

X.25 has no protection of its own, so the gateway applies the per-service profile on the legs it controls:

- **An X.25 service** is identified by its called X.121 address and the CUD protocol identifier. The gateway maps it to a named service in Service Descriptors, which gives it a profile from the same key sets.
- **The XTP leg** uses that profile, as above.
- **An XOT leg (TCP, port 1998)** can meet the profile with TLS bound to the same service keys, or the gateway refuses the call.
- **A native serial, LAPB or LLC2 leg** cannot be protected. The gateway refuses a call whose service requires authentication or encryption, unless the operator has declared that physical circuit protected. That declaration is recorded in the decision receipt.
- **Never a silent downgrade.** A refusal is an X.25 CLEAR with the right cause, and the local receipt names the profile that was not met.
