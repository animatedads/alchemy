# Changelog

## 0.1-dev2

- Repaired QueueRexx binding method signatures for ooRexx runtime compatibility: `use strict arg` no longer uses method invocations as default expressions.
- `bindClient` now accepts an empty `remoteRequestQueue` default and resolves it inside the method to `FirewallControlContract~REQUEST_QUEUE`.
- `bindServer` now accepts an empty `remoteReplyPrefix` default and resolves it inside the method to `FirewallControlContract~REPLY_PREFIX`.
- No firewall semantics changed: exact `/32` remains 1440 minutes, enclosing `/24` remains 10 minutes, protected sources remain fail-closed, and the HTTPS/RexxOS caller still has no rule/duration authority.
- This repair is based on live ooRexx qualification on ED209I reported against dev1: the unmodified dev1 failed while loading `FirewallControl.cls`; a temporary review copy with these signature repairs passed the semantic qualification.

## 0.1-dev1

- Added independent `firewall.control/0.1` gateway authority.
- Added fixed `/32=1440m` and containing `/24=10m` hostile-source policy.
- Added protected-source veto and nftables protected-set defence in depth.
- Added authenticated QueueRexx/Queue Fabric `FIREWALL` service binding.
- Requester cannot choose CIDR, timeout or shell/firewall command.
- Added request identity binding, peer ACL, replay suppression and changed-content conflict rejection.
- Added INPUT and FORWARD nftables sets with native timeout expiry.
- Added receipt and replay ledgers plus deterministic memory provider tests.
