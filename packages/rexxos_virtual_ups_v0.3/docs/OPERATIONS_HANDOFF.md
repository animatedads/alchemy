# Operations handoff, 2026-10-29: Virtual UPS and mail evidence

## Current artifact truth

- Source: `packages/rexxos_virtual_ups_v0.3` on `animatedads/alchemy` after manual GitHub publication.
- Validated only on local Linux/Python; 22 unit tests and one isolated demo. Not installed on ed209j, ed209d or any MU/MI.
- No ambient cloud/LDAP/HTTPS/SMTP/IMAP/XTP access and no host-power authority. The `ups.capabilities` response declares each absent binding.
- The Alchemy autobuilder is not running; this publication does not depend on it.

## Why the TOPS-20 warning is a mail investigation, not a UPS driver request

User-provided console contains:

```
SJ  0: **** MAILS(4) 21:09:44 ****
SJ  0: [SCHEDULER]:        Waiting for UPS:
SJ  0: **** OPR(3) 21:09:44 ****
```

The pinned KLH10 `doc/klt20.txt` section `TOPS-20 TCP/IP - OTHER NOTES` shows this same periodic notice, names the offending `MX` process in its `SYS` example, and says `7-PTYCON.ATO` invokes it. A separate public TOPS-20 operator transcript also shows `MAILS(4)` running `MX` with the same warning (https://blog.onodera.asia/2013/). Neither document defines the acronym UPS, captures a failed outgoing message, nor shows a guest electrical-power read. No changes to PTYCON, MX or the installed guest are authorized by this observation.

The new diagnostic reports raw capture `source_sha256`, byte count, exact scheduler notice line numbers, nearby `MAILS`/`OPR` *proximity* only, and explicit unverified power/mail claims. Do not promote this to actual mail-server telemetry. To examine a saved capture:

```
python3 bin/virtual_ups.py inspect-tops20 --log /path/to/saved-console.txt
```

## Required handoffs to infrastructure owners

| Domain | What this lane can provide | Owner acceptance still required |
| --- | --- | --- |
| SMTP/IMAP | historical `MX` context and a read-only text observation | actual Rasen Falcon native SMTP/IMAP process, signed sender/relay policy, mail delivery receipts |
| LDAP | no bindings | LDAP service/authn/authz and caller identity proof |
| private-CA HTTPS | no bindings | owned HTTPS endpoint, CA/chain, hostname and CNAME coverage, login authorization |
| XTP / MU-to-MI | synthetic power event formats only | authenticated FIRST, service rights and route admission across L2/IPv4-protocol-36/UDP GCP policy |
| website | nothing deployable from UPS | owned site publisher/host/domain/HTTPS rollout verification |
| Instrumentation Mesh | local source events and guest observation shapes | service registration, correct observation envelope, authenticated transport and acceptance |
| Time Service | deterministic logical seconds, **not** UTC | independently attested time correlation API |
| KLH10/TOPS-20 | saved console observations | DEC hardware signaling contract and separated guest-device adapter tests |

No owner-module code was modified as part of this work. Component-specific coordination went via the **writable Rasen Falcon** MCP, not the read-only alchemyrexx catalogue.

## Independent qualification gates

1. Run tests and demo in a disposable work directory before treating the reference as viable:
   `python3 -m unittest discover -s tests -v` and `./bin/run-demo.sh`.
2. Confirm `capabilities` and `ups.capabilities` indicate no binding and no physical authority, even without an initialized journal.
3. Inspect a *copy* of the captured console; compare returned SHA-256 to original bytes; never treat adjoining MAILS/OPR as cause of warning.
4. For any on-host experiment, use a dedicated unprivileged account and private state directory. Never run as root and never enable network listeners through this reference.
5. Do not implement a real guest interrupt, monitor shutdown, MU drain, cloud stop or host power action without a separate accepted interface contract, a policy authority and rollback rehearsal.
