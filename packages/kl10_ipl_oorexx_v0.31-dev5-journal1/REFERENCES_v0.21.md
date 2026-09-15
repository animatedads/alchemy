# References for KL10 IPL ooRexx v0.21

External historical/reference material is used as an oracle, not vendored.

- Richard Cornwell's PDP-10/KL10 simulator (`bscottm/rcornwell-sims`), notably
  `PDP10/kx10_cpu.c` for KL10 instruction semantics and
  `PDP10/kx10_defs.h` for 36-bit masks/field definitions.
- DECsystem-10/DECSYSTEM-20 Processor Reference Manual (June 1982), used for
  standard accumulator, effective-address and BLT notation.
- Preserved DEC TOPS-20 V7.0 installation tape `BB-H137F-BM`, used only as an
  external test fixture and not redistributed.

## Current v0.21 cross-checks

Cornwell's opcode `0251` (`BLT`) is the direct semantic oracle. The selected
AC supplies `source,,destination`; the resolved E is the inclusive destination
limit. The KL10 path precomputes the architectural final AC, then performs a
forward sequence of ordinary memory reads and writes while incrementing both
halves of the local transfer pointer. v0.21 preserves this ordering and routes
every read/write through `KL10AddressSpace`.

This ordering is intentionally tested in cases that expose shortcuts: a BLT
into addresses `1..3` must update live AC1..AC3 rather than hidden backing
core; an overlapping forward copy must observe words changed by earlier
iterations rather than a snapshotted source; and a BLT whose destination is
its own pointer AC must allow the later memory write to replace the precomputed
AC value.

The preserved MTBOOT image is the integration oracle. AC14 enters BLT as
`047000,,000001`, E is `000007`, and seven source words from `047000..047006`
are deposited at addresses `1..7`. Because those addresses are the section-zero
fast-memory window, the resulting words become AC1..AC7. The architectural BLT
final pointer is `047007,,000010`. Existing instructions then execute through
`JRST 1`; the next fetch comes from AC1 and executes `200612,,000000` (`MOVE`).
The v0.21 boundary is the next live fast-memory word, AC2 at address `000002`: `250611,,000000` (`EXCH 14,0(11)`), decoded but not executed.

Earlier release invariants remain in force: section-zero addresses below `020`
resolve through live accumulator state; ordinary and device memory activity
uses one authoritative address space; paging remains disabled on the current
MTBOOT path; unsupported indirect/extended/channel behavior rejects rather
than being guessed.
