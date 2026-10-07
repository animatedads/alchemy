# ED209 field matrix

`run_field_matrix.sh` is the controller-side machine-to-machine XTP qualification harness.

## Managed-node access invariant

Every field operation goes through the existing per-node helper. Provide a local inventory file and configure `XTP_SSHNODE` or make `sshnode.sh` available on `PATH`; host inventory is intentionally not included in this public source tree:

```sh
sshnode.sh NODE_A 'remote command'
sshnode.sh --transfer NODE_A LOCAL_PATH REMOTE_PATH
sshnode.sh --pull NODE_A REMOTE_PATH LOCAL_PATH
```

The harness does **not** call `ssh` or `scp` directly and does not attempt to reconstruct usernames, ports, keys, jump hosts, or other per-node SSH configuration. Override only the helper pathname with `XTP_SSHNODE=/path/to/sshnode.sh` when required.

It first transfers the exact `xtp-local` binary from this package to every enabled inventory node and records whether the host can create native IPv4 protocol-36 and AF_PACKET/EtherType-0x817D sockets. It then exercises every directed host pair twice:

* Level 3: native XTP directly in IPv4 protocol 36.
* Level 4: the same XTP packet engine encapsulated in UDP.

Layer 2 pair tests are deliberately opt-in. Put two endpoints in the same non-empty `l2_domain` and provide/discover the interfaces and destination MACs. The harness never infers Ethernet adjacency from an IP subnet. This is intended for RexxOS MI/MU private L2 domains and similar explicit same-fabric cases.

Typical controller run:

```sh
make clean all
qualification/field/run_field_matrix.sh
```

Raw protocol-36 and AF_PACKET require `CAP_NET_RAW` on each field host. By default the harness probes `sudo -n` and, where available, uses it to give only `cap_net_raw+ep` to the copied test binary via `setcap`. Set `XTP_REMOTE_PRIV=none` to disable that step, or `XTP_REMOTE_PRIV=sudo` to require passwordless sudo.

Results are written under `qualification/field/results-YYYYMMDD-HHMMSS/` with per-host evidence, per-directed-pair client/server logs, `host-capabilities.tsv`, `pair-matrix.tsv`, and `SUMMARY.txt`.

A native protocol-36 failure is not automatically called a firewall failure. The matrix uses `NO_RESPONSE_OR_FILTERED` unless evidence distinguishes a local permission failure. Provider/security-setting diagnosis remains a separate evidence step.
