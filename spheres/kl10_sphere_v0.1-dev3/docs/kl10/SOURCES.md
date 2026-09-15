# KL10 sphere source register

Verified for this sphere on 2026-09-02.

## Tier 1 — primary architecture / hardware

- **DECsystem-10/DECSYSTEM-20 Processor Reference Manual, June 1982** — instruction set, effective addresses, BLT, KL10 paging, APR/PI, channels and RH20.  
  https://www.bitsavers.org/pdf/dec/pdp10/TOPS10_softwareNotebooks/vol05/AA-H391A-TK_DECsystem-10_DECSYSTEM-20_Processor_Reference_Jun1982.pdf
- **KL10 Technical Reference Manual, August 1984** — KL10-R hardware and configuration. Its general description states a normal minimum of 512K words except the 1091.  
  https://www.bitsavers.org/pdf/dec/pdp10/KL10/EK-OKL10-TM_KL10_TechRef_Aug84.pdf
- **Extended Addressing on the DECSYSTEM-20 — Dan Murphy** — Model-B 30-bit PC, local/global addressing, IFIW/EFIW and section-aware instruction behavior.  
  https://github.com/PDP-10/tops20-build/blob/456fed1f22b196f987375d35a1145f4d41c35703/src/documentation/eapgmg.mem
- **DEC STD 159 Massbus Specification** — Massbus-level I/O reference.  
  https://bitsavers.org/pdf/dec/standards/DEC_STD_159_Massbus_Specificaton.pdf

## Tier 1b — production microcode preservation

- **alanmimms/kl10-microcode** — recovered final TOPS-20-capable KL10 Model-B microcode plus microcode-level emulator.  
  https://github.com/alanmimms/kl10-microcode
- **BLT microcode** — normal and clear-core BLT paths, restart/fixup sequencing.  
  https://github.com/alanmimms/kl10-microcode/blob/master/kl10-source/blt.mic

## Tier 2 — TOPS-20 V7 guest-oracle source

Pinned repository revision: `456fed1f22b196f987375d35a1145f4d41c35703`.

- `src/monitor/pagem.mac` — paging and CST/map management.
- `src/monitor/pagutl.mac` — PGRINI, memory scan, MEMOFF.
- `src/monitor/aprsrv.mac` — APR/PI and page-fault handling.
- `src/monitor/postld.mac` — POSTLD image relocation and PNRCOD.
- `src/monitor/boot.mac` — BOOT, memory probing and monitor loading.
- `src/monitor/stg.mac` — storage layout and monitor data structures.

Repository: https://github.com/PDP-10/tops20-build

## Tier 3 — secondary reference implementations

- Richard Cornwell `sims`, `PDP10/kx10_cpu.c` — KL/KI/KS CPU and pager implementation.  
  https://github.com/rcornwell/sims/blob/master/PDP10/kx10_cpu.c
- `PDP10/kx10_rh.c` — RH10/RH20 implementation.  
  https://github.com/rcornwell/sims/blob/master/PDP10/kx10_rh.c
- `PDP10/kx10_df.c` — DF10/channel common routines and explicit NXM memory-boundary checks.  
  https://github.com/rcornwell/sims/blob/master/PDP10/kx10_df.c

These are implementation evidence only. If they conflict with primary DEC documentation or production microcode, record the conflict rather than silently adopting the reference-emulator behavior.
