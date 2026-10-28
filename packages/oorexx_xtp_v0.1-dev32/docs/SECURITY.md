# XTP per-service protection (dev32)

**Architecture:** Tom Dyer (decision D-07, 28 October 2026). **Coding:** Claude (Opus 5.5). **Written by:** Claude (Opus 5.5), 28 October 2026.

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
outcome = keys~refresh        -- SOURCE ('ldap' or 'file'), COUNT, ERRORS
```

- **Order.** Sources are tried in order, and the first that works wins. A source that raises an error has failed, and the next is tried.
- **One step.** A source replaces all of its keys at once (`KeyTable::replace_source`, `xtpNativeKeyReplaceSource`). Everything is checked first; a bad key refuses the whole set and changes nothing. There is no moment at which a service has lost its old keys but not received the new ones.
- **When LDAP works,** keys loaded from a file are removed, because the file is only a fallback.
- **When LDAP fails,** keys already fetched from it stay until they expire, and the file is loaded as well.
- **What "works" means for LDAP.** The bind and the three searches (principals, key sets, generations) succeed, and at least one XTP key is found. Zero keys counts as a failure, because it usually means the bind DN cannot read the key sets or the base DN is wrong. Any problem with an XTP key set or generation also fails the whole fetch, and every problem is reported:
  - a key set must be owned by a `service:<name>` principal that is in the directory, sit under that principal's entry, and have an entity ID no other set has;
  - a usable generation must sit under its key set's entry, and have a 16-hex-digit key ID, readable dates, and a secret reference that starts with `secret://xtp/<service>/` (the prefix is an argument);
  - Secret Broker must resolve the secret to 64 hex digits.

  The placement rules mean a principal that may write only its own subtree cannot attach a key to another service. The prefix rule means the directory cannot make this process fetch an unrelated secret with its own broker authority.
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

## Listener policy

| Case | Result |
| --- | --- |
| Service has keys, open is unprotected | DIAG 17 AUTH_REQUIRED, unauthenticated |
| Service has keys, open is protected but weaker than the profile | DIAG 17 AUTH_REQUIRED, authenticated under the open key |
| Service's keys expired or revoked, but its profile is sticky | Protected opens are dropped (no valid key); unprotected opens get DIAG 17 AUTH_REQUIRED |
| `require_protection` set, service has no keys, open is unprotected | DIAG 17 AUTH_REQUIRED |
| Service has no keys and no profile, open is unprotected, no `require_protection` | Accepted unprotected, as in dev31 |

The opener uses the stronger of the service's profile and what it asks for; asking for `none` never lowers the profile. If there is no active key, `open_session` refuses before sending anything.

**Key lifetime.** About once a second each endpoint checks that the key of every protected context is still in the key table and valid. A context whose key was revoked, has expired or has left the table is closed at that end, and the other end is told. A RETIRING key is still valid, so rotation does not end sessions: move the old key to RETIRING, wait for its sessions to finish, then remove it.

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

## Evidence

- `make test-security`: P1 to P20.
- `tests/test_xtp_service_keys_rexx.sh`: the ooRexx path, from a real LDAP server (the estate's own `LdapWireServer`, with the Identity Directory and Secret Broker) to an encrypted session, then the key-file fallback, then a wrong secret being refused.

`VALIDATION_DEV32.txt` has the figures.

## Not yet

- **One-way messages and streams** (`send_message` and `Listener`) are still unprotected. Sessions came first because the gateway needs them; messages and streams are next (dev33).
- **Multicast** needs group keys, which is a separate design.
- **Per-client keys from LDAP.** The key file and `install` take a principal, but the LDAP mapping reads only service-owned key sets. Gateway mode-B temporary credentials will need key sets owned by `service:<name>/client:<principal>`; that is proposed, not built.
- **Push updates.** LDAP sync and persist are not wired in; `refresh` is called by the owner.
- **Clock dependency.** An open more than 30 s from the responder's clock is dropped.
- **Flooding.** Protected opens are rate limited before any cryptography. A flood from many forged addresses can still use up the total open rate, which delays new opens, not established sessions. Packets for an established context that fail verification cost one AEAD check each, about 1 to 2 µs, and are never answered.
- **Rekeying.** A context keeps its keys until it ends or its long-term key goes. The 64-bit counter cannot run out in practice.
- **Principals from LDAP.** Service-owned key sets are installed with no principal: any holder of the service key may use them. Per-client key sets come with gateway mode B.
- **Secrets in ooRexx memory.** The C++ side wipes every copy of a secret it makes. ooRexx strings cannot be wiped: the key sources drop their references straight after installing, and the interpreter frees them later.

## X.25: the same strategy

X.25 has no protection of its own, so the gateway applies the per-service profile on the legs it controls:

- **An X.25 service** is identified by its called X.121 address and the CUD protocol identifier. The gateway maps it to a named service in Service Descriptors, which gives it a profile from the same key sets.
- **The XTP leg** uses that profile, as above.
- **An XOT leg (TCP, port 1998)** can meet the profile with TLS bound to the same service keys, or the gateway refuses the call.
- **A native serial, LAPB or LLC2 leg** cannot be protected. The gateway refuses a call whose service requires authentication or encryption, unless the operator has declared that physical circuit protected. That declaration is recorded in the decision receipt.
- **Never a silent downgrade.** A refusal is an X.25 CLEAR with the right cause, and the local receipt names the profile that was not met.
