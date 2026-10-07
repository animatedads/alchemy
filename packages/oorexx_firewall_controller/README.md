# ooRexx Queue Fabric Firewall Controller v0.1-dev2

API: `firewall.control/0.1`

Independent gateway-side firewall authority for hostile-source reports from
Queue Fabric-connected services.

Policy is fixed at the authority:

* source `/32`: **1440 minutes**;
* containing `/24`: **10 minutes**.

The client reports only a hostile IPv4 source plus optional reason/evidence.
It cannot choose a CIDR, timeout or firewall command.

## Important deployment invariant

Populate the gateway's protected-source registry with your administration IP
and/or management `/24` before enabling mutation.  `FirewallControlService`
rejects protected-source requests and the nftables layer also ACCEPTs protected
sources before hostile sets.

## Queue Fabric

`FirewallQueueRexxBinding` is intentionally duck-typed against the existing
QueueRexx peer mesh and consumes `QueueRexxPeerMeshRuntime~bindServiceRoute()`.
Security domain is `FIREWALL`; transport remains Queue Fabric `queue.transport/2`.

The pattern matches existing service-neutral QueueRexx adapters rather than
inventing another network protocol.

## Files

* `src/FirewallControl.cls` — contract, policy, protected registry, replay,
  receipts, providers, QueueRexx client/server binding.
* `libexec/firewall-nft` — narrow nftables mutation helper.
* `tests/test_firewall_control.rex` — semantic qualification with memory provider.
* `tests/test-helper.sh` — helper/static checks.
* `etc/firewall-controller.conf.example` — deployment policy example.
* `docs/ARCHITECTURE.md` — authority and trust boundary.

## HTTPS-side call

Once the HTTPS classifier has sent its final 303, it submits only:

```rexx
reply = firewallClient~blockHostileSource("GATEWAY", peerIp, -
                                         "HOSTILE_HTTPS_SCAN", evidenceId)
```

No nftables code belongs in the HTTPS service or RexxOS guest.

## Qualification status of this archive

This build environment does not contain ooRexx or nftables.  The shell helper
is syntax-checked and the archive has static contract checks here.  The ooRexx
semantic test is supplied but is **not claimed executed** in this container.
Run on an ooRexx 5.3 host:

```sh
cd tests
rexx test_firewall_control.rex
```

Then qualify the QueueRexx route against the gateway and one RexxOS/HTTPS peer.
