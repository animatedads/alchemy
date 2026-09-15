# IBM 4361 ooRexx machine model — v0.3 recovery2 + journal integration

An inspectable, serialisable, replayable IBM System/370-family machine model, using the IBM 4361 as the initial physical/model identity.

This is deliberately **not** a Hercules port. IBM documentation is the normative architectural reference and Hercules is an independent executable/source oracle. The ooRexx object model owns a separate explicit machine-state contract designed for deterministic freeze/load/replay/fork.

## v0.2 classes

- `IBM4361Machine` — composition root and operator/IPL state.
- `IBM370CPU` — PSW, GPRs, CRs, FPR slots, prefix and execution state.
- `IBM370PSW` — raw 64-bit PSW value; finer BC/EC interpretation remains oracle-driven.
- `IBM370Storage` — sparse byte-addressed main storage plus raw storage-key state.
- `IBM370Clock` — guest TOD / CPU timer / comparator detached from host wall clock.
- `IBM370CCW0` — exact raw/decomposed 8-byte System/370 format-0 CCW plus flag interpretation.
- `IBM370IOResult` — explicit device/channel completion result.
- `IBM370ChannelProgram` — current CCW address, chaining progress, residual/status and step count.
- `IBM370ChannelSubsystem` — channel/device ownership and active-program state.
- `IBM370IODevice` — base device freeze contract.
- `IBM370IPLMemoryDevice` — deterministic sequential-record development fixture; **not a tape emulation**.
- `IBM4361State` / `IBM4361FrozenState` — explicit SHA-512-sealed architectural checkpoint format.

## Shared libraries are references, not payload

The package contains no copy of Alchemy Objects, ooRexx Crypto, msqlshim, or Journal Pointed State. Tests require the shared components by reference:

```sh
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8 \
OOREXX_CRYPTO_ROOT=/path/to/oorexx_crypto_v0.1 \
MSQLSHIM_ROOT=/path/to/msqlshim_v0.21a \
JOURNAL_POINTED_STATE_ROOT=/path/to/oorexx_journal_pointed_state_v0.1 \
./run_tests.sh
```

The runner adds their `src/` directories to `REXX_PATH`. Packaging fails if shared Alchemy/Crypto/Journal sources are carried inside this component.

## v0.2 executable IPL boundary

System/370 IPL is now modeled as a real channel program:

```text
operator LOAD
   |
   v
implied Read IPL CCW
  command = X'02'
  address = 0
  count   = 24
  CC + SLI
   |
   v
absolute 000000..000017 receives first record
   |
   +-- 000000 IPL PSW (not loaded yet)
   +-- 000008 fetched CCW1
   +-- 000010 fetched CCW2
   |
   v
channel program executes/follows CC/TIC
   |
   v
successful final channel completion
   |
   v
IPL PSW loaded; CPU starts
```

The implementation currently supports command chaining, TIC, SLI/skip interpretation and deterministic sequential Read (`X'02'`) against the development fixture. Data chaining and IDA fail closed until implemented.

## Replay boundary

The acceptance test deliberately freezes **between CCW1 and CCW2**:

```text
begin IPL
execute CCW1
freeze S                  media cursor = record 2
                            CCW address = 000010
        +------------------------+
        |                        |
        v                        v
 continue original          load S fresh
 execute CCW2               execute CCW2
        |                        |
        +---------- diff --------+
                   ==
```

The final checkpoint must be byte-identical on both branches.

## Media policy

Historical guest media is never embedded in this emulator package. Device state/checkpoints carry media identity and digest information and, once real file-backed devices are added, will require the referenced media to match before resume. This is the same fail-closed rule used for other future-determining machine state.

The Jay Maynard OS/360 MVT turnkey distribution from CBT Tape is the intended first historical guest corpus. Its Hercules configuration will be used as configuration evidence, not copied into the emulator runtime design.


## Optional live journal / rewind layer

`IBM4361Journal.cls` adds an **in-process** journal-pointed execution history using the external Journal Pointed State component.  It is deliberately separate from `IBM4361State` durable freeze files.

- journal checkpoints are cheap live pointers for rewind/fork/retry;
- RAM history is stored as reversible changed ranges and storage-key deltas;
- CPU/clock/machine/channel control state is journalled as compact event state;
- a live missing-method repair can install code and rewind to the pre-instruction point;
- taking a durable `IBM4361State` freeze from a journal-restored machine uses the normal freeze codec and contains **no journal history**.

See `docs/JOURNAL_INTEGRATION.md`.

## Journal-pointed live archaeology

The current executor supports object-scope live instruction insertion and
replacement specifically so a journal checkpoint can be rewound while trial
code remains installed.  See `docs/LIVE_ARCHAEOLOGY.md` and
`tests/test_executor_live_method_replacement.rex`.  Durable freeze files remain
a separate whole-machine evidence/replay format.

## Live method withdrawal and promotion equivalence

Live archaeology now supports explicit object-scope method withdrawal as well
as insertion/replacement.  `removeLiveMethod()` is intentionally outside
journalled machine state, so withdrawing a hypothesis survives CPU/RAM/device
rewind just as installing or replacing one does.  This permits an accepted live
candidate to be removed and the permanent class implementation to be executed
from the identical journal-restored microstate.  Safety11 uses that technique to
prove live/permanent equivalence for System/370 AL (`X'5E'`).

### Safety13 status

Safety13 adds System/370 X'D4' NC / And Character, qualified through exact
real-MVT journal retry and candidate-to-permanent equivalence.  The next
observed boundary is X'00' at IA zero; this is explicitly an interruption /
control-flow investigation, not an instruction implementation request.  See
`HANDOVER_SAFETY13.md`.

### Safety14/Safety15 status

Safety14 resolves the deliberate X'00' fetch at address zero as a qualified
System/370 BC-mode operation-exception program interruption, without creating
OP00. Safety15 adds X'1E' ALR / Add Logical Register after exact real-MVT
journal retry and candidate-to-permanent equivalence. The current next boundary
is X'FF' at low-core IA `000020`; it is intentionally left untouched pending
control-flow and architectural classification. See `HANDOVER_SAFETY14.md` and
`HANDOVER_SAFETY15.md`.

### Safety16 current checkpoint
Primary X'FF' is now independently qualified as a guest-visible BC-mode
operation exception, delivered through the generic program-interruption path;
there is no OPFF method.  Exact MVT retry advances 6,211 instructions to the
next untouched boundary X'C4' at IA X'000042'.  See HANDOVER_SAFETY16.md.

### Safety17 current checkpoint
System/370 primary X'C4' is now independently qualified as a guest-visible
BC-mode operation exception through the generic program-interruption path; no
OPC4 method exists.  Exact MVT retry advances 1,727 instructions to the next
untouched boundary X'62' at IA X'000050'.  See HANDOVER_SAFETY17.md.

### Safety20 current checkpoint
System/370 X'D1' MVN / Move Numerics is now qualified by exact real-MVT journal
rewind/retry, destructive-overlap and 24-bit-wrap regressions, live-method
withdrawal/permanent equivalence, and a whole-trajectory permanent-source
replay.  The recorded guest byte `10` at `0004E7` becomes `18` from source
`B8` at `0005D1` with CC0 unchanged.  MVT then executes 1,565 further
instructions to X'65' at IA `000066`, ICOUNT `532961`.  No OP65 method exists.
See `HANDOVER_SAFETY20.md`.
### Safety21 current checkpoint
System/370 primary X'65' is now qualified as a guest-visible BC-mode operation
exception through the generic program-interruption path; no OP65 method exists.
Recovered exact MVT replay writes program-old PSW `00040001A000006A`, loads the
complete program-new PSW `00040000000002CA`, and advances 1,703 instructions to
the untouched X'02' boundary at IA `00006E`, ICOUNT `534665`.  X'02' remains
pending authoritative System/370 table confirmation and has no OP02.  See
`HANDOVER_SAFETY21.md`.


### Current continuation checkpoint

Safety22 qualifies primary System/370 X'02' as an operation exception through the generic interruption seam, with no OP02. The next untouched frontier is X'70' at 000082 / ICOUNT 539172; see HANDOVER_SAFETY22.md.

### Safety24 current checkpoint

Safety24 repairs architectural specification-exception propagation for a
transient instruction executed by System/370 EX.  At the exact real-MVT
`44 @ 0004B6 / ICOUNT 539205` boundary, EX targets invalid-R1 STE
`70E005C84780`; the repaired generic path saves PGMOLD
`00040006800004BA`, loads PGMNEW `00040000000002CA`, and adds no OP70.
Independent permanent-source replay then executes 102,530 more instructions to
the next genuine missing instruction: X'4B' SH / Subtract Halfword at
`FFB5A8 / ICOUNT 641735`.  See `HANDOVER_SAFETY24.md`.
