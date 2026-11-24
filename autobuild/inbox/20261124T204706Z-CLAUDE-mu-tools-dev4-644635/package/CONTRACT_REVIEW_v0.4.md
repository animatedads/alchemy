# cats contract v0.4: review of cats1's 24 Nov audit

Architecture: Tom Dyer. Audit tool and this review: Claude (Opus 5.5). Audit run: Codex
(REQ-00005627, after Tom's approval). Status: ACCEPTED by Tom Dyer, 24 Nov 2026 ("continue"); su: "on for the moment, almost clear to go".

cats1 had 105 findings: 2 processes, 4 units, 19 forbidden programs, 63 packages of programs with no witness, 17 files. Every one is placed below in exactly one bucket (checked by script: none unplaced, none in two buckets):

- **WITNESS**: a reason it is there, written into the contract (v0.4 draft). Most end at a
  milestone: M8 (ssh replaced by XTP), stage C (own kernel and boot), stage D (static
  init), or the image.
- **REMOVE**: unjustified and removable with apt. Removal is an order marked NEEDS TOM'S
  DIRECT APPROVAL, after the read-only simulation (REQ-00005681, V2) shows what else it
  would take with it.
- **IMAGE**: unjustified, but in an Essential package (or one systemd needs); apt cannot
  remove it safely. The stripped image leaves it out. It stays a FORBIDDEN finding until then.
- **TOM**: a proposal Tom has not ruled on.

## Processes (2)

| finding | bucket | reason |
|---|---|---|
| sudo | WITNESS | sshnode.sh orders run sudo; until M8 |
| su | WITNESS (Tom, 24 Nov: on for the moment; almost clear to go) | your root console session during bring-up |

## Units starting at boot (4)

| finding | bucket | reason |
|---|---|---|
| nftables.service | WITNESS | it loads the fence (mu_fence). Missing from v0.3: my gap |
| grub-common.service, grub-initrd-fallback.service | WITNESS | GRUB bookkeeping, until stage C |
| systemd-pstore.service | WITNESS | keeps kernel panic records after a crash: evidence |

## Forbidden programs (19)

| programs | package | bucket |
|---|---|---|
| gpg | gpg | REMOVE |
| gpgconf, gpg-connect-agent | gpgconf | REMOVE (simulation: takes gpg and libgpgme11 with it; apt needs only gpgv) |
| hexdump, hd | bsdextrautils | REMOVE |
| dbus-send, dbus-monitor | dbus | removed with dbus at M8 (logind needs the bus until then) |
| busctl | systemd | IMAGE |
| script, scriptreplay, scriptlive | bsdutils (Essential) | IMAGE |
| setarch, i386, x86_64, linux32, linux64 | util-linux (Essential) | IMAGE |
| perl, perl5.34.0 | perl-base (Essential) | IMAGE (debconf needs it while apt is here) |
| od | coreutils (Essential) | IMAGE |

## Programs with no witness (63 packages)

| packages | bucket | reason |
|---|---|---|
| dbus (dbus-daemon) | WITNESS | with logind, until M8 (the process was witnessed; the program was not: my gap) |
| apparmor | WITNESS | SecOp's profile set; the unit was already witnessed |
| gpgv | WITNESS | apt checks signed indexes, until the image |
| debconf ucf sensible-utils adduser debianutils diffutils findutils sed mawk init-system-helpers libc-bin login passwd libpam-modules-bin libpam-runtime base-files base-passwd install-info ncurses-bin hostname bsdutils sysvinit-utils util-linux tzdata | WITNESS | dpkg, maintainer scripts and the base system, until the image |
| alternatives: awk | WITNESS | the link to mawk |
| systemd-sysv | WITNESS | init is PID 1, until stage D |
| mount e2fsprogs logsave kmod | WITNESS | boot-time mounts, fsck, modules, until stage D |
| grub-common grub2-common grub-pc grub-gfxpayload-lists initramfs-tools initramfs-tools-core linux-base efibootmgr mokutil sbsigntool shim-signed cpio zstd xz-utils dosfstools | WITNESS | the boot chain, until stage C |
| azure-vm-utils nvme-cli | WITNESS | Azure's NVMe disk naming; until the image |
| bsdextrautils (col column look ...) apt-utils gawk shared-mime-info uuid-runtime iputils-ping locales gettext-base libcap2-bin cryptsetup-bin dmsetup | REMOVE | no witness: no MU duty uses them. The simulation decides |
| iptables (and alternatives: arptables, ebtables, ip6tables, iptables ...) | REMOVE | the fence is nftables; the iptables layer is unused; removes cleanly (simulation) |
| openssh-client (scp sftp ssh ssh-agent ...) | WITNESS until M8 | Tom's PC has OpenSSH 10.5, so scp uses SFTP and the MU's own scp is not needed, but purging openssh-client also purges openssh-server (simulation). It goes with ssh at M8 |

## Files no package owns (17 shown)

| finding | bucket | reason |
|---|---|---|
| /usr/local/man, src, games, etc, sbin | WITNESS | empty directories base-files makes |
| /root/.profile, /root/.bashrc | WITNESS | root's profile, for the break-glass console |
| /root/.bash_history | stays a finding | removed at M8: an MU keeps its record in logs, not shell history |
| /root/snap/lxd (current, 41283, common) | REMOVE | left by a snap install; snapd is gone |
| /home/azureuser/... (profile, bashrc, history, sudo marker, motd) | WITNESS | the bring-up account, until M8 |

## Replay of cats1's recording (24 Nov, 19:03)

| contract | findings |
|---|---|
| v0.3 | 105 |
| v0.4 | 32: 19 forbidden, 9 packages with no witness (6 to remove, iptables with its 31 alternatives links, and dbus's other 4 programs until M8), /root/.bash_history, /root/snap/lxd (3) |
| v0.4 after the removals (expected) | 16: 14 forbidden (12 in Essential packages, busctl, and dbus-send/dbus-monitor until M8), dbus (4 programs, until M8), /root/.bash_history |

## Removal set (cleared by simulation, REQ-00005739)

gpg gpgconf (and libgpgme11) bsdextrautils apt-utils gawk shared-mime-info iputils-ping locales iptables, and /root/snap.
Kept after simulation: openssh-client (takes openssh-server), libcap2-bin (takes chrony and iproute2),
uuid-runtime (takes nvme-cli), gettext-base (breaks the signed boot chain), cryptsetup-bin and dmsetup (initramfs).

## What happens next

1. Tom strikes or accepts. The [TOM] lines are proposals.
2. When REQ-00005681 returns, I replay the cats1 recording against v0.4: what should remain
   is only the REMOVE and IMAGE items, and the TOM items Tom strikes.
3. A removal order (NEEDS TOM'S DIRECT APPROVAL) for the REMOVE list that the simulation clears.
4. mu-tools dev4 publishes the accepted contract.
