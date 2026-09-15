# References for KL10 IPL ooRexx v0.20

External historical/reference material is used as an oracle, not vendored.

- Richard Cornwell's PDP-10/KL10 simulator (`bscottm/rcornwell-sims`), notably
  `PDP10/kx10_sys.c` for EXE/EXB loaders and opcode names, and
  `PDP10/kx10_cpu.c` for KL10 CPU, PAG/APR and I/O semantics.
- Cornwell `PDP10/kx10_rh.c` and `PDP10/kx10_tu.c` for the RH10/RH20 +
  TM03/TU10 channel/controller topology used as an architectural cross-check.
- DECsystem-10/DECSYSTEM-20 Processor Reference Manual (June 1982), used for
  standard effective-address, accumulator, shift/rotate and halfword notation.
- Preserved DEC TOPS-20 V7.0 installation tape `BB-H137F-BM`, used only as an
  external test fixture and not redistributed.

## Current v0.20 cross-checks


Cornwell's opcode cases `0500..0577` are the direct semantic oracle for the
new halfword family. The ooRexx implementation preserves the regular
left/right source and destination structure, the preserve/zero/ones/sign-extend
quartets, AC=0 suppression on `S` forms, and real modify/store memory writes.
The KL extended-address `XHLLI` behavior is intentionally outside this
section-zero bounded model.

Cornwell's opcode cases `0240..0246` are the direct semantic oracle for the
new shift/scan family. `ASH`/`ASHC` preserve the sign bit and raise overflow
when a left shift discards bits inconsistent with the sign; `ROT` and `ROTC`
use modulo-36/modulo-72 rotation; `LSH`/`LSHC` are logical; `JFFO` stores the
leading-zero count in AC+1 and branches only when the selected AC is nonzero.
The ooRexx regression covers positive and negative counts, large rotation
counts, pair operations, overflow flags and AC17-to-AC0 pair wrap.

Cornwell's KL10 `dev_pag()` is the oracle for the expanded PAG object. `CONI`
returns `(EBR >> 9)` plus page-enable/TOPS-20 mode bits. `CONO` loads EBR from
the low `017777` field, sets those two pager-mode bits, and invalidates both
translation caches. `DATAO` can load UBR and context/previous-section state.
v0.19 implements the exact EBR and MTBOOT UBR transitions while paging is off,
records invalidation generations, and rejects controls that would require the
unimplemented page translator or unmodeled context switching.

Cornwell's KL10 `dev_apr()` is the oracle for APR PIA/enable/flag state and the
`0200000` whole-machine reset control. The bounded model retains its explicit
reset transition and implements the ordinary interrupt-control state needed by
the current path.

The preserved MTBOOT image is the integration oracle. v0.20 executes twenty-six
real instructions, observes EBR=`047000`, UBR=`047000` with paging still
disabled, executes `HRRI 14,1` and indexed `HRLI 14,7000(16)`, and reaches
AC14=`047000,,000001`. The next untouched instruction is
`040036 251600,,000007` (`BLT 14,7`).

Earlier release invariants remain in force: section-zero addresses below `020`
resolve through live accumulator/fast-memory state; all memory writes use the
authoritative address space; `JSP`/plain indexed `JRST`, complete ADD/SUB,
Boolean/test and MOVE families remain covered by their existing regressions.
