# Queue Fabric Firewall Controller v0.1-dev2

The component is an independent gateway-side firewall authority.  An HTTPS
service, including one inside RexxOS/QEMU, has **no nftables authority**.  It
reports one hostile source address through the existing QueueRexx peer mesh.

```text
HTTPS / RexxOS / QEMU
        |
        | firewall.control/0.1 BLOCK_HOSTILE_SOURCE(ip,evidence)
        v
QueueRexx bindServiceRoute()
Queue Fabric queue.transport/2
security domain FIREWALL
        |
        v
Gateway FirewallControlService
        |
        +-- authenticated peer ACL
        +-- from_node == authenticated Queue Fabric peer
        +-- protected-source veto
        +-- derive exact /32 locally -> 1440 minutes
        +-- derive containing /24     ->   10 minutes
        +-- replay/conflict ledger
        +-- receipt
        v
nftables provider
```

The request deliberately contains **no prefix length and no timeout**.  A guest
can report `198.51.100.148`; it cannot ask the gateway to block `0.0.0.0/0`,
change the timeout, choose an nftables table, or submit a shell command.

## Queue Fabric boundary

The optional `FirewallQueueRexxBinding` follows the established service-neutral
QueueRexx pattern: `bindServiceRoute()`, persistent messages, security domain
`FIREWALL`, correlation by request ID, and server-owned reply routing.  It does
not create a second socket or trust relationship.

## Local policy

For every accepted hostile IPv4 report:

* exact source IPv4: 1440 minutes;
* containing IPv4 /24: 10 minutes.

Protected sources are checked before mutation and are also installed in an
nftables `protected4` set whose ACCEPT rule precedes both hostile DROP sets.
This is defence in depth against a controller defect.

The nftables helper hooks both INPUT and FORWARD because the protected HTTPS
service may be the gateway itself or a QEMU/RexxOS guest routed through it.

## Replay semantics

An identical durable request ID is answered as `REPLAY` without refreshing the
nftables timeout.  Reusing the same request ID with changed content is rejected
as `REQUEST_ID_CONFLICT`.  Supply a persistent replay ledger on the gateway so
these semantics survive service restart.

## Privilege boundary

Run the ooRexx service unprivileged.  Grant only the small `firewall-nft` helper
the required gateway firewall authority (root wrapper/system service/sudo rule,
depending on deployment policy).  Do not grant the RexxOS guest firewall
privilege.
