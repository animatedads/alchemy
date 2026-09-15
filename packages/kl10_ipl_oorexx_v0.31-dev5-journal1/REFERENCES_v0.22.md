# References for KL10 IPL ooRexx v0.22

External historical/reference material is used as an oracle, not vendored.

- DECsystem-10/DECSYSTEM-20 Processor Reference Manual notation for accumulator
  and effective-address operations.
- PDP-10 instruction reference description of `EXCH` as `C(AC) >< C(E)`.
- DEC KL10 diagnostic source (`dakadm.mac`) EXCH tests, which explicitly verify
  that the old effective-address word enters AC and the old AC word enters E.
- Preserved DEC TOPS-20 V7.0 installation tape `BB-H137F-BM`, used only as an
  external test fixture and not redistributed.

## Current v0.22 cross-checks

Opcode `250` (`EXCH`) exchanges the complete 36-bit contents of the selected
accumulator and resolved effective address.  Effective-address calculation is
completed before either destination changes.  The implementation captures both
old values before performing either architectural write, then routes the E-side
write through `KL10AddressSpace` so section-zero addresses `0..17` octal remain
live accumulator aliases rather than hidden backing memory.

The focused regression covers three cases: an indexed ordinary-memory exchange,
an exchange where E is another live accumulator, and a self-alias exchange where
AC and E designate the same fast-memory word.  The latter two cases are intended
to kill sequential-MOVE shortcuts that would mishandle aliasing.

The accepted v0.21 historical tape state stops at address `000002` (AC2) with
`250611,,000000`, decoded as `EXCH 14,0(11)`.  At that boundary AC11 is
`000000,,011000` and AC14 is zero, so the instruction resolves E=`011000`.
The exact 36-bit word resident at `011000` is intentionally not invented here:
the external tape fixture was unavailable in this build environment, therefore
the 34th preserved-tape step is not claimed as executed in v0.22 validation.

Earlier invariants remain in force: section-zero addresses below `020` resolve
through live accumulator state; every ordinary operand and memory destination
uses one authoritative address space; unsupported indirect/extended behavior
rejects rather than being approximated.
