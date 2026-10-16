# SSH-over-XTP v0.1 candidate 2 — implementation boundary

Date: 2026-10-15. Depends on **oorexx_xtp_v0.1-dev21**, SHA-256
`3512185ce8af99c9c84136186d6c87357961bdcc79def6415fb2ffc9e742bb44`.

## Components

* `ssh-xtp client` is an OpenSSH `ProxyCommand`-compatible raw stdin/stdout bridge.
* `ssh-xtp gateway` accepts XTP application frames on a configured listener peer,
  enforces a root-controlled local policy file, validates a 256-bit keyed HMAC
  challenge/response, then opens **127.0.0.1** to the configured `sshd` port.
* `ssh_xtp_policy.py` is a **local root-only** atomic policy editor with JSONL
  intent/commit audit. This is **not** yet the estate-wide signed controller.
* No public TCP SSH listener is opened or requested by the bridge.
* The bridge consumes existing `xtp::SocketProvider` send/listen; route selection
  remains inside XTP. No alterations to XTP packet format or Rexx socket API.

## Stream protocol

Frames: `SXTP` + version 1 + type + reserved + session-id(u64) + seq(u64) +
length(u32) + body (up to 1024 bytes) + HMAC-SHA256 (32 bytes). Integers are
big-endian. HMAC covers the full header and body. Wrong MAC, version, lengths or
unexpected state means reject. Authentication secret is a 32-byte random PSK,
hex encoded in an owner-restricted 0600 file on each side. Do not reuse an SSH
private key as the bridge key.

1. Client OPEN (session ID, authorized client ID, seq=0)
2. Gateway CHALLENGE (32 random bytes, seq=0) if policy is OPEN
3. Client PROOF echoes challenge (seq=1), authenticated by HMAC
4. Gateway checks policy again, opens only localhost sshd and emits READY (seq=1)
5. Both directions send ordered DATA frames starting at seq=2; FIN is a
   directional half-close. No transport ACK constitutes SSH authorization.
6. Policy SEALED terminates active sessions and emits an authenticated SEALED
   control message. LOCKED prevents new authentication while active sessions
   continue. OPEN allows new admissions.

Each XTP transaction uses a distinct packet KEY within the current process,
independent of the 64-bit application frame sequence. libxtp provides packet
acknowledgement and retransmission; bridge sequence checks prevent duplicate
writes. The bridge never converts a failed XTP acknowledgement into success.

## Security boundary

* A production policy file must be regular, **root-owned**, and not writable by
  group/other. Missing, malformed, unreadable, or permissively owned files are
  treated as SEALED. Its containing directory must be root-owned and not
  group/world-writable, and should be outside gateway write permissions.
* The `--allow-user-owned-policy-for-test yes` option is ONLY for isolated
  non-production tests; it must never appear in a deployed service unit.
* The gateway should run as a dedicated unprivileged user with a restricted key
  and access only to its XTP listener, routing configuration and localhost sshd.
* Server host-key validation, user authentication, encryption, shell handling,
  SSH port forwarding and SFTP are **OpenSSH responsibilities**, unchanged.
* XTP itself is still reachable; its native framing/listener must withstand
  unauthenticated malformed traffic and resource exhaustion. The HMAC gate is
  an application admission control and is NOT XTP-wide cryptographic security.
* A single gateway process binds one preconfigured client identity/secret and
  handles one session; it must be restarted for the next session. Multiclient
  routing, dynamic per-client key lookup, forwarding and independent stream
  continuity across path migration are **not implemented**.
* This candidate has no signed estate policy distribution, no integration with
  RexxOS authority keys, no HA gateway, and no audited live ED209 roll-out.
  Those are separate admission gates, not features assumed complete.
* A client sending a replayed OPEN cannot complete admission with an old proof:
  the server's challenge is freshly random and bound to authenticated frames.
  Application DATA has per-session ordered sequence verification.
* Traffic volume and client ID remain potentially observable at transport edge.
  The SSH payload is end-to-end encrypted by OpenSSH **after its handshake**.

## Deployment order — absolutely no automatic firewall changes

1. Stage and rebuild the pinned source on a private MU. Keep current recovery
   route and public SSH access until independent out-of-band access is verified.
2. Confirm transport pair routes in both directions and that gateway access is
   limited by authenticated peer and the root-controlled local policy.
3. Create bridge PSK securely: `umask 077; openssl rand -hex 32 > shared.hex`.
   Distribute over a pre-existing authenticated channel; do not print it in logs.
4. Configure sshd to listen exclusively on `127.0.0.1` (or separate tightly
   firewalled management interface). Verify effective listeners with `ss -lntp`.
5. Test an actual OpenSSH host-key-verifying connection, command execution,
   disconnection, reconnect, SFTP and key rotation. Validate no forwarding
   bypass, policy transitions, XTP path failover, and security audit.
6. **Only then** block public TCP/22 using provider firewall + host firewall,
   after testing out-of-band console/recovery and rollback in the same window.
7. Never conflate inability to scan SSH with invulnerability: XTP remains a
   public-facing attack surface if reachable publicly.

## Qualification states

PASS: C++17 build, direct XTP-over-UDP binary half-close/echo, wrong HMAC
admission refusal, OPEN/LOCKED/SEALED, active LOCKED drain and active SEALED
termination. The local echo service in tests is an SSH-like fixture, **not sshd**.

NOT_RUN: live OpenSSH/sshd, raw36 and Ethernet, remote ED209 nodes, mixed-carrier
failover during established SSH streams, SELinux/AppArmor sandbox, transport
fuzzing, production root-owned policy rollover, comprehensive session scale.

## Candidate 2 delta

Only validation harness, release metadata, documentation and checksums
are extended. `src/ssh_xtp.cpp` and bridge wire protocol remain unchanged.
`tests/test_openssh.py` provides a full SSH handshake to an ephemeral
loopback `sshd`; XTP admission and OpenSSH client authentication are distinct.
A host-key mismatch must be rejected by OpenSSH despite successful XTP
admission.
