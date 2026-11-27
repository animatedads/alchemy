# Standing rules for the grid push (25 November 2026)

Architecture and approval: Tom Dyer. Written down by: Claude (Opus 5.5).

## R1. cats2 (ed209l) is approved in full

Tom Dyer, 25 Nov 2026, 15:04 ("agreed re cats2 entirely"), approving this wording:

> Everything inside cats2 (ed209l), including rebooting and deallocating it, is
> approved. Keys and the Auth, the Azure network security group, and every
> other node are not.

What this means for an order:
- An order that changes only cats2 (ed209l, 20.118.224.14) cites R1. It needs
  no separate approval from Tom.
- Rebooting and deallocating cats2 are covered.
- **Not covered**, so each still needs Tom's direct approval:
  - creating, copying, rotating or using key material, and the Auth;
  - the Azure network security group, and any Azure setting outside the VM;
  - every other node, including cats1 (ed209g) and ed209f (ed209k: see R6;
    cats1: see R7);
  - the WAN forwarder.
- An agent that is unsure whether an action is inside R1 asks Tom.

## R2. Port 22 on cats2 closes only when two things are proven

1. cats2 can be rebuilt from its image with nobody logging in.
2. The Azure serial console works on cats2 as a break-glass.

Until both are proven, port 22 on cats2 stays open. cats1 keeps port 22 until
SSH over XTP has survived a reboot, as decided earlier.

## R3. The image

- Kits are built in the Ubuntu 22.04 build container, which matches cats.
- The image is a stock Ubuntu minimal plus a first-boot script that installs
  the kits from the repository and applies the MU contract.
- Nothing on a cats node carries build tools.
- The contract is versioned inside the image. An enforcing boot never disables
  the controller's own dependencies.

## R4. Advertise, then decide

- Controllers advertise what they have: RAM, CPU, fabric space and links.
- A cluster arbitrator decides where each demand runs. It is a main and spare
  pair on separate sites, like LDAP.
- MUs never bid against each other with nobody deciding.

## R5. Recovery by rebuild

- If cats2 breaks, it is redeployed, not repaired.
- Offline suites stay as regression tests. They are no longer a ladder every
  change must climb before it touches cats2.

## R6. ed209k may host LDAP and xtpd

Tom Dyer, 25 Nov 2026, 16:17, said "We can use ed209k as well". That was the
answer to where LDAP.main and LDAP.spare should run. Written down by Claude
(Opus 5.5) in this narrow reading:

> Installing and running xtpd, an LDAP role (main or spare), their kits from
> the repository and their files inside ed209k is approved for the grid push.
> Rebooting ed209k, keys and the Auth, Vultr account and firewall settings,
> and anything else on ed209k are not.

What this means for an order:
- An order that installs or runs xtpd, the ooRexx LDAP server
  (oorexx_ldap_identity) or the role file on ed209k cites R6. It needs no
  separate approval from Tom.
- **Not covered**, so each still needs Tom's direct approval:
  - rebooting or reinstalling ed209k;
  - key material and the Auth (the role file's test key is key material);
  - Vultr settings and the firewall;
  - any other change on ed209k.
- If Tom widens R6 to match R1, this section is rewritten, not stretched.

## R7. The witness is a rolling role; cats1 may hold it

Tom Dyer, 25 Nov 2026, 17:11, said "Agreed regarding rolling witness". That
answered the proposal in v0.2 that the LDAP pair needs a third vote outside
the pair, with cats1 as the candidate. Written down by Claude (Opus 5.5) in
this narrow reading:

> The witness is a role, like LDAP.main. It is held by a node that is neither
> main nor spare. When a promotion or move puts the witness's node into the
> pair, the witness role rolls to another node outside the pair. Installing
> and running xtpd and the witness service, with their kits from the
> repository and their files, inside cats1 (ed209g) is approved. Port 22 on
> cats1, rebooting cats1, keys and the Auth, the Azure network security group,
> and anything else on cats1 are not.

What this means for an order:
- An order that installs or runs xtpd or the witness service on cats1 cites R7.
  It needs no separate approval from Tom.
- Placement now: LDAP.main on ed209k (R6), LDAP.spare on cats2 (R1), witness
  on cats1 (R7). That is three nodes on three sites.
- A witness never holds main or spare at the same moment. If no node outside
  the pair is left to hold it, there is no promotion: the spare stays STALE
  and the event is logged.
- **Not covered**, so each still needs Tom's direct approval: port 22 on cats1
  (it stays open until SSH over XTP has survived a reboot), rebooting cats1,
  key material and the Auth, the NSG, and any other change on cats1.

## R8. XTP through the firewalls

Tom Dyer, 25 Nov 2026, 19:35: "lets run the backup firewall change to enable 47036 udp / also ensure that all machines will accept xtp from 82.68.79.12 / my machine WILL do xtp out". Written down by Claude (Opus 5.5):

> 1. ed209k accepts XTP over UDP from cats2 (20.118.224.14), as a backup carrier alongside raw IP protocol 36.
> 2. Every ed209 machine accepts XTP from Tom's workstation, 82.68.79.12. That means IP protocol 36 and XTP over UDP. The workstation sends XTP out.

**Amended 25 Nov 2026, 21:30 (Tom: "continue" to Claude's proposal):** XTP over UDP uses the estate's commissioned port **62801**, not 47036. Claude (Opus 5.5) had picked 47036 for xtpd without checking the estate's convention. The two 47036/udp rules added on ed209k at 19:4x are removed once ed209k listens on 62801 (kit v0.1-dev5, `item1_carrier.rex`) and cats2 is allowed on 62801. Tom's existing 62000:63000/udp workstation rule on ed209k already covers 62801.

What this means for an order:
- An order that adds exactly these allows cites R8. Removing or changing any other firewall rule is not covered.
- Each machine is first inventoried read-only, because the host firewalls differ (ufw, firewalld, plain iptables) and some machines also sit behind a cloud firewall (Azure NSG, AWS security group, Google firewall, Oracle security list). The change commands are then written per machine.
- Where only a cloud firewall can carry protocol 36, the narrowest rule that provider offers is used. Azure NSG rules offer only Tcp, Udp, Icmp, Esp, Ah or Any, so protocol 36 from 82.68.79.12 needs an Any rule for that one source address. The report says so.
- Port 22 rules are never touched under R8.

**Status, 27 Nov 2026 (Claude (Opus 5.5)).** The cloud side of R8 is done. Order E (REQ-00006325), with Tom's direct "yes", applied `cloudctl xtp NODE --add-only` on ed209a (which covers ed209b, on the same OCI security list), ed209c, ed209d, ed209i, cats1 (ed209g), cats2 (ed209l), ed209e and ed209j. Each node's re-plan reads NO CHANGE, and no source was removed: ed209f's UDP 62801 rule is kept everywhere. Order B had already moved ed209k to 62801. Still open: the host firewalls of ed209f, ed209h and cats1 (`mu_fence`), ed209b's own host (unreachable), and ED209M as a new peer (order G plans, REQ-00006467).

## R9. ED209M (newyork1.rasenfalcon.com) is approved in full, inside the machine

Tom Dyer, 27 Nov 2026, 15:03 ("you have a machine to play with: ED209M aka newyork1.rasenfalcon.com ... runs kvm"), then "continue" at 15:16 to Claude's proposed wording:

> Everything inside ED209M is approved: installing, configuring, running VMs
> and rebooting its guest OS. Keys and the Auth, the Clouvider panel and its
> network settings, the host firewall's port 22 rule, and every other node are
> not.

What this means for an order:
- An order that changes only ED209M (185.195.106.30, AlmaLinux 10.3, Clouvider VPS.16 New York, nested KVM) cites R9. It needs no separate approval from Tom.
- Covered: packages, services, users and files on ED209M; KVM guests (MIs) and their disks and networks inside ED209M; ED209M's own host firewall, except its port 22 rule; rebooting ED209M from inside the OS.
- **Not covered**, so each still needs Tom's direct approval:
  - creating, copying, rotating or using key material, and the Auth. That includes the SSH host key and a mailbox credential for a job runner;
  - the Clouvider panel: reinstall, rescue, power, network and billing;
  - the host firewall's port 22 rule;
  - every other node, and any firewall rule elsewhere that admits ED209M (that is R8 work, as in order E).
- An agent that is unsure whether an action is inside R9 asks Tom.
