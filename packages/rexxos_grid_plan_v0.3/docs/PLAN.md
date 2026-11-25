# The grid push: plan of 25 November 2026

Architecture: Tom Dyer. Hitlist: Claude (Fable 5.2). Review and changes: Claude
(Opus 5.5), agreed by Tom Dyer ("continue", 15:04). Standing rules:
STANDING_RULES.md.

## Aim

- **The boot is the test.** Every restart of cats2 must end with cats2 on the
  grid, with nobody logging in.
- **One thin slice end to end** (the failover cat app) comes before any breadth.

## Build order

1. ChatGPT 1: xtpd at boot, with the bootstrap role file.
2. Claude 1: the controller.
3. ChatGPT 3: the MI image and launcher.
4. Claude 2: the arbitrator live.
5. ChatGPT 4: a package job on RTO2.
6. Then the rest.

Codex runs the boot test on every restart of cats2.

## Claude (Opus 5.5)

1. **Controller.** One ooRexx process, the only unit enabled at boot. It holds
   the arbitrator, the NewShell endpoint, the RTO2 runner and the log
   subscription, and logs every step through oorexx_logging from the first
   boot. It talks to xtpd; it does not replace it. Its record of work is the
   journal with the lease (rexxos_arbitrator dev6).
   **Done when** a cold boot reports MU_READY over XTP with no login.
2. **Arbitrator live.** Machine state comes from the log pump. Real effectors
   exist for three steps only: start MI, stop MI, and provide or release swap.
   **Done when** a demand produces a running MI, and the journal shows each
   step's checked effect.
3. **Grid placement.** Controllers advertise capacity, and the cluster
   arbitrator (a main and spare pair) decides (R4).
   **Done when** cats1, cats2 and ed209k place a job three ways, and it moves
   when one of them withdraws.
4. **Enforcing audit.** At boot, anything without a witness is disabled, not
   just reported. That includes sshd once item 1 has passed twice and R2 is met.
   **Done when** the audit is THIN with zero findings, and port 22 is closed on
   cats2.
5. **Single submit point.** `grid~submit(package)` from NewShell on any node.
   **Done when** the same package submitted from three places gets a job id and
   a receipt each time.

## ChatGPT

1. **xtpd at boot** with the bootstrap role file (rexxos_arbitrator dev5
   design: main, spare, epoch, version, seeds, trusted keys).
   **Done when** cats2 resolves LDAP.main fresh after a cold boot, with no
   manual step.
   **Status (25 Nov 2026):** ChatGPT's role component (xtpd_bootstrap
   v0.1-dev1) has been qualified by Claude (Opus 5.5) and published. Binding it
   into xtpd is Claude's job, as xtpd's author: the xtp.roles exec-hook
   service, the LDAP role probe and the role file at start, in xtpd v0.1-dev2.
   **Placement:** LDAP.main on ed209k (Vultr: reliable, not Spot, native
   XTP; R6). LDAP.spare on cats2 (Azure Central US, Spot; R1). Two providers,
   two sites. The item 1 test is then a cats2 cold boot that resolves ed209k
   as LDAP.main FRESH.
   **Witness (R7, agreed 25 Nov 17:11):** the witness is a rolling role held
   outside the pair, on cats1 for now. It is not needed for item 1, which does
   no promotion. It is needed before the spare can promote itself.
2. **The real Auth.** Ed25519, signing in the su-locked account, with delegates
   per host.
   **Done when** one lock stops every remote job on the grid.
3. **MI image and launcher.** A stripped guest that boots straight into the
   RTO2 runner and is found by its service address. If cats2's Azure size has
   no nested virtualisation, the first MIs run as Linux namespace containers
   under the same job contract.
   **Done when** the controller starts two MIs and both register.
4. **A package job on RTO2.** Two MIs on two MUs, with snapshots streamed to the
   standby.
   **Done when** deallocating cats2 mid-job finishes the job elsewhere with no
   resubmission.
5. **The Storage Fabric for real.** A compare-and-swap lease, the journal, and
   two copies of outputs.
   **Done when** the outputs survive cats2 vanishing.
6. **Pump events.** RAM, pressure, link state and MI death as log events,
   feeding Claude's item 2. Providers dev17 and dev18 (switching audit on and
   the audit listener) are the start of this.

## Open, for read-only checks first

- cats2's Azure size, and whether it allows nested virtualisation (KVM).
- The current state of xtpd and of the fabrics on cats1, cats2 and ed209k.
- Whether the Azure serial console works on cats2 (R2).

## Risks

- **Skipping the rehearsal ladder** makes node failures harder to diagnose.
  The controller logs every step from the first boot, and the journal records
  each step's checked effect.
- **Disabling things at boot** can lock cats2 out. That is acceptable only
  because recovery is by rebuild (R5) and port 22 closes only under R2.
