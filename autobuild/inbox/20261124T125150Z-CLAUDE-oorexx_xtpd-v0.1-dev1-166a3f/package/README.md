# xtpd v0.1-dev1: the XTP network service daemon

One multi-threaded daemon per XTP node. It takes registrations, service requests and peerages, and runs hooks. Applications never handle a carrier socket, a key, a route or a firewall rule.

- **Architecture:** Tom Dyer (24 November 2026).
- **Coding:** Claude (Opus 5.5), 24 November 2026.
- **Written by:** Claude (Opus 5.5).
- **Design:** the xtpd design doc (https://claude.ai/artifact/5xdnepoEfSABaQoCxcByNe) and the `xtpd` sphere.

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
