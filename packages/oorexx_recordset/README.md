# ooRexx RecordSet v0.1-dev6

First-class cross-platform **RecordSet** object for ooRexx.

## Architectural rule

`RecordSet` owns record semantics. `Stream` owns stream semantics.

- MVS: native logical records from DD/dataset/member storage.
- non-MVS: pseudo records over ordinary files.

The component remains separate from `FileNative` / `StreamNative`.

## dev3 milestone

dev3 implements the first real native-MVS driver slice rather than routing MVS
records through stdio:

```text
.RecordSet
    -> RecordSetNativeMvs.c          MVS object semantics
    -> RecordSetMvsDriverQsam.c      C90 driver/metadata layer
    -> RecordSetMvsQsam.asm          real QSAM/DCB bridge
```

The QSAM bridge currently targets **caller-allocated sequential DD names**.
Dataset/member allocation remains a distinct later service.

Implemented native behavior:

- `DD:NAME` identity;
- INPUT / OUTPUT / APPEND (`OPEN EXTEND`);
- F / FB / V / VB logical records;
- real OPEN-populated RECFM/LRECL/BLKSIZE metadata;
- QSAM locate-mode GET/PUT;
- V/VB RDW removal on read and construction on write;
- fixed-record padding with EBCDIC blank `X'40'`;
- record positioning by rewind-and-skip;
- caller-owned DD allocation remains caller-owned;
- EBCDIC-safe DD/dataset/member name parsing without assuming A-Z/a-z are
  numerically contiguous.

`RECFM=U`, dynamic dataset allocation, and PDS-member allocation are not claimed
in dev3.

## Public Rexx surface

`.RecordSet~open(resource [, mode [, options]])`

Instance methods include `read`, `write`, `readStem`, `writeStem`, `position`,
`recordNumber`, `recordCount`, `eof`, `close`, metadata accessors, and
`isNativeRecordSet`.

EOF is distinct from a zero-length record.

## Portable backend

The portable backend remains the pseudo-record reference implementation:

- LF terminates a record;
- CRLF is accepted without exposing delimiters;
- unterminated final line is a record;
- empty records are valid;
- no implicit character-set conversion.

## Validation actually run in dev3

- strict C90, warning-as-error compile of the MVS semantic + QSAM driver stack;
- QSAM C-driver contract test: PASS;
- full MVS semantic stack against fake low-level QSAM bridge: PASS;
- VB metadata decode and `LRECL-4` public payload limit: PASS;
- fixed-record EBCDIC `X'40'` padding assertion: PASS;
- portable backend regression: PASS;
- ooRexx native wrapper host syntax compile against pinned ooRexx API: PASS;
- `RecordSetNativeMvs.c` through cc370 `-S`: nonempty S/370;
- `RecordSetMvsDriverQsam.c` through cc370 `-S`: nonempty S/370;
- target-side C environment probe through cc370 `-S`: nonempty S/370.

The handwritten QSAM assembler has **not** been executed on MVS from this
session. `tests/dev3/mvs/QUALIFY.JCL` is supplied as the complete real-MVS
qualification job; no MVS execution claim is made until JES evidence is obtained.

See `docs/MVS-QSAM-BRIDGE.md` and `docs/RECORDSET-SPEC.md`.


## dev4 live-MVS repair

The first unchanged ED209Z qualification run (RSQQUAL job 56) reached MVS 3.8J
and failed in ASM1 RC=16 before link/run. dev4 repairs the assembler/JCL deck:

- IFOX00 object output uses `SYSGO` and `OBJECT,NODECK`;
- exported ENTRY directives follow the actual symbol definitions;
- the `DCBD` mapping macro is at module end so its generated DSECT cannot capture executable storage;
- the handle DSECT explicitly resumes `RSETQSAM CSECT`;
- each callable entry has an entry-local R12 base and a common-CSECT R10 base.

Use `tests/dev4/mvs/QUALIFY.JCL` for the next ED209Z run.  Do not run ED209ZZ
until the ED209Z evidence is captured. See `CODEX_ED209Z_DEV4_RERUN.md`.


## dev5 live-run repair

Dev5 is based on ED209Z job 57 evidence. It adds explicit RSHNDL DSECT addressability, card-safe Assembler XF source, regenerated embedded ASM1, and stricter link gating. Run `tests/dev5/mvs/QUALIFY.JCL` on ED209Z only.


## dev6 live-MVS repair

See `DEV6_NOTES.md` and `CODEX_ED209Z_DEV6_RERUN.md`.  dev6 removes the redundant explicit R8 base operands from RSHNDL DSECT references left by dev5.
