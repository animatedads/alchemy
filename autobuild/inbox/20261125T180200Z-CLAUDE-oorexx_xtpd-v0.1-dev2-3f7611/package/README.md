# xtpd v0.1-dev2: the XTP network service daemon

One multi-threaded daemon per XTP node. It takes registrations, service requests and peerages, and runs hooks. Applications never handle a carrier socket, a key, a route or a firewall rule.

- **Architecture:** Tom Dyer (24 November 2026).
- **Coding:** Claude (Opus 5.5): dev1 on 24 November 2026, dev2 on 25 November 2026. The role component dev2 binds in (`xtpd_bootstrap` v0.1-dev1) was coded by ChatGPT and qualified by Claude (Opus 5.5).
- **Written by:** Claude (Opus 5.5).
- **Design:** the xtpd design doc (https://claude.ai/artifact/5xdnepoEfSABaQoCxcByNe) and the `xtpd` sphere.

## What dev2 adds: the bootstrap role file (grid item 1)

| Piece | dev2 |
| --- | --- |
| Config | `node NAME`, `role_file PATH`, `role_keys PATH` (TEST keys, `KEYID SECRETHEX`), `role_timeout_ms N` |
| Role record | ChatGPT's `XtpRoleBootstrap`, unchanged: `ROLE|LDAP|main|spare|epoch|version|seeds|keys`, verified before use, replaced only through AtomicFile (FULL, noFollow) |
| `xtp.roles` | exec hook `libexec/xtp_roles.rex`: serves this node's exact signed envelope. The asker verifies it, never the hook |
| Catch-up | at start, xtpd asks the record's main, spare and seeds over `xtp.roles`, and accepts only a verified newer record |
| `ldap.role` | exec hook `libexec/ldap_role.rex`: answers `CONFIRM SELF ROLE EPOCH VERSION` only when this node holds ROLE in its own record at exactly that epoch and version, and its local ooRexx LDAP server (oorexx_ldap_identity) answers a real LDAPv3 bind; otherwise `DENY REASON` |
| Resolve | main confirmed: FRESH. Only the spare: STALE. Neither: UNAVAILABLE. READY only on FRESH, never from the file alone. No promotion and no DNS change |
| Control | `STATUS` carries the role; `ROLE` re-runs the check (both root only): `rexx bin/xtp_request.rex ROLE` |
| Failure | a refused or broken role file leaves xtpd running, degraded and not READY |

Placement for item 1 (grid plan v0.3): LDAP.main on ed209k (R6), LDAP.spare on cats2 (R1), and the witness on cats1 (R7). The witness is not used yet.

Limits, said plainly:
- The role key is a shared-key HMAC (`TEST_ONLY_HMAC`): a test boundary, not the real Auth (ChatGPT item 2). Whoever holds the test key can also sign.
- A probe answer is authenticated as coming from a holder of the `ldap.role` service key, not from that one node. Per-node proof also needs the real Auth.
- A node does not confirm itself: on LDAP.main's own node, xtpd's role status is UNAVAILABLE, which is correct, since nothing outside it has confirmed it.
- No announcements yet: a node learns of a newer record at start, or on `ROLE`.

Found and fixed during dev2 qualification:
- The role check first ran inside `Xtpd~run`, which holds the daemon's guard. The listener thread needs that guard (`track`) for every session, so a node waiting on its own fetches stopped accepting probes from others. The check now runs in `startRoles`, which is unguarded, and the status line never waits for a check. The end-to-end test is the control: it failed before the fix and passes after.
- A role trap caught the HALT raised inside a method by SIGTERM, so the daemon would not stop. Traps now pass interrupts on, and the test checks that both daemons stop on SIGTERM.
- The dev1 SSH test asked for at least 270,000 bytes received, but the payload is 266,668 bytes, so it passed only where SSH added enough overhead. It now uses the payload size.
- `tests/run_all.sh` used native libraries shipped inside source packages, which fail on another C library (Ubuntu 22.04). It now rebuilds every native part from source.


## What dev1 does

| Input or output | dev1 |
| --- | --- |
| Registrations | `services.txt`: `SERVICE CLASS PROTECTION exec /absolute/program args...` |
| Peerages | `peers.txt`: `PEER LAYER CARRIER ADDRESS` (3 raw36 IPv4, or 4 udp IPv4:port) |
| Keys | the XTP key file (LDAP first is dev2) |
| Service requests | unix socket; `OPEN SERVICE PEER` answered with a connected descriptor (SCM_RIGHTS), or `ERR reason` |
| Hooks | exec: the program gets one end of a socketpair as stdin and stdout, xtpd pumps the other end to the session |
| Firewall | each peerage's address added to the fence set at start, all withdrawn at stop, through `libexec/xtpd_firewall.rex` |
| Receipts | every accept, open, refusal and close, through `oorexx_logging` |

A session is admitted only if its service is registered, its source is a peerage, and its protection meets the registration. A protected open with the wrong secret is dropped by libxtp before xtpd sees it.

SSH needs nothing else: `ssh.management` is registered with the hook `/usr/sbin/sshd -i`, and the client side uses OpenSSH's `ProxyUseFdpass` with `bin/xtp_request.rex` (see `etc/ssh_config.example`). sshd still checks its host key and the user's key; the XTP service key decides who reaches sshd at all. No TCP listener exists.

## Built only from estate packages

| Package | For |
| --- | --- |
| `oorexx_xtp` v0.1-dev38 | sessions (`XtpSession.cls`), service keys |
| `oorexx_unix_socket` v0.6 over `oorexx_foreign_runtime` v0.22.6 | the request socket, socketpairs, peer credentials, descriptor passing |
| `oorexx_process` v0.1-dev2 | hooks started on a descriptor; reap and signal |
| `oorexx_logging` v0.7 | receipts |

The pump is ooRexx: two threads per session. `UnixSocket~recvMessage` is unguarded, so one thread reads the socket while the other writes it, and a blocking receive releases the interpreter (checked 24 November 2026: the main thread ran 1,354,199 loops while another thread waited in `recv`).

## Not in dev1

- LDAP as the source of registrations, peerages and keys; the emergency-file writer.
- Operating states, shedding by class and `reconcile()`.
- `xtp.provision` peerages.
- Hook kinds `rexx` and `fd`.
- The cats failover and quorum decision.

## Run

```sh
rexx bin/xtpd.rex /etc/xtpd/xtpd.conf
```

SIGTERM or SIGINT stops it cleanly: listeners closed, the request socket removed, peerages withdrawn from the fence.

## Tests

`tests/run_all.sh` builds the dependencies in a temporary directory and runs:

- `tests/test_units.rex`: names, routes, the three file formats, the route table, refusal of a symbolic link (no root, no network).
- `tests/test_local_ssh.sh`, over UDP and over raw IP protocol 36 on loopback. Two daemons ("cats1" and "ed209k"), real OpenSSH through `ProxyUseFdpass`, `sshd -i` as the hook. It checks:
  - no TCP listener;
  - the fence flushed and the peerage added at start;
  - a command, a 300 kB download and a 270 kB upload intact, the receipts showing the bytes crossed XTP;
  - encryption under the service key;
  - refusal of an unknown service, an unknown peer and a wrong secret;
  - a clean stop.

  It needs root, because `sshd -i` reads its host key.

Result on 24 November 2026, Claude's workspace, ooRexx 5.3.0 trunk: all pass over both carriers. Nothing has run on cats1 or ed209k yet.
