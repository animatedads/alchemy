# MVS QSAM bridge — dev3

This component deliberately follows the classic MVS record model instead of
projecting a POSIX byte stream underneath RecordSet.

The first native slice is caller-allocated sequential DD I/O.  The bridge uses
QSAM locate mode and therefore receives one logical record at a time.  Physical
blocking remains an access-method detail.

For fixed records (`F`/`FB`), `RecordSet` sees exactly `LRECL` bytes.  The higher
MVS semantic layer pads short writes with EBCDIC blank (`X'40'`) before invoking
the low-level driver.

For variable records (`V`/`VB`), QSAM locate-mode records include the four-byte
record descriptor word.  `RecordSetMvsQsam.asm` strips that RDW on reads and
constructs it on writes.  The public RecordSet payload therefore never contains
RDW bytes.  Real MVS `LRECL` metadata is preserved, while the maximum public
payload is `LRECL - 4`.

The dev3 assembler bridge supports:

- caller-allocated DD names;
- INPUT, OUTPUT and EXTEND open modes;
- F, FB, V and VB records;
- logical record GET/PUT;
- CLOSE;
- rewind implemented as CLOSE, restore clean input DCB, OPEN INPUT;
- OPEN-populated `LRECL`, `BLKSIZE` and `RECFM` metadata.

`RECFM=U` is explicitly not claimed yet.  Dataset/member allocation is also not
part of this slice; that remains above/beside the QSAM DD driver so allocation
ownership stays distinct from stream lifetime.

The assembler is intentionally written for MVS 3.8J / Assembler XF conventions.
It does not use later AMODE/RMODE directives.  Its standard MVS macro dependencies
are `DCB`, `DCBD`, `OPEN`, `CLOSE`, `GET`, `PUT`, `GETMAIN` and `FREEMAIN`.

The contract was checked against the OS/VS2 MVS Data Management Macro
Instructions Release 3.8 documentation.  In particular, that documentation
allows register-form DCB addresses for QSAM GET/PUT and defines EXTEND as the
append-style OPEN option.  The DCB record-format mapping uses the documented
DCBRECFM F/V/U and blocked bits.

## Tasking boundary

The dev3 assembler entry routines use static save areas and are intentionally
single-task/non-reentrant.  This matches the initial ooRexx/MVS rule of one
interpreter per MVS task.  A later multitasking qualification must replace these
with reentrant save-area management before claiming cross-task sharing.

## Real MVS qualification

`tests/dev3/mvs/QUALIFY.JCL` is self-contained: it assembles the QSAM bridge and
its standalone probe with IFOX00, link-edits them with IEWL, executes against a
real `RSIN` DD and FB/LRECL=80 `RSOUT` DD, then prints the output dataset.

Expected completion codes are:

- ASM1: 0
- ASM2: 0
- LKED: 0 or 4
- GO: 0

The printed RSOUT record must begin with `ONE`.

This JCL has not been run from the build environment because there is no remote
MVS/Hercules execution connector in this session.  The package therefore makes
no MVS execution claim until that job is run and its JES evidence is captured.
