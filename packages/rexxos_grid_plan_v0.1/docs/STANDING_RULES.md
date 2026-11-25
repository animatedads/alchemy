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
  - every other node, including cats1 (ed209g), ed209k and ed209f;
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
