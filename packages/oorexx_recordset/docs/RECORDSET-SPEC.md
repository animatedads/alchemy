# Cross-Platform RecordSet Object Specification v0.1

## Purpose

`RecordSet` is a first-class ooRexx object representing an ordered collection of logical records.  MVS maps the object to native dataset/DD/member records.  Non-MVS platforms project ordinary files into pseudo records.

## Normative rules

1. Record boundaries are semantically significant.
2. RecordSet does not expose a fictitious universal byte-stream storage model.
3. EOF is distinct from a zero-length record.
4. Record positions are one-based logical record positions, not byte offsets.
5. A backend may report record count as unknown.
6. Text encoding conversion is not implicit; record payload remains native bytes unless a later explicit conversion option is selected.
7. MVS block/RDW/BDW mechanics are implementation details, not Rexx-visible record bytes.
8. Closing an externally allocated MVS DD must not deallocate it.
9. Stream/CHARIN projection may consume a RecordSet, but must not redefine RecordSet itself.
10. Classic MVS Rexx DD/dataset/EXECIO behavior is the compatibility reference for the MVS backend.

## Public object surface

- class `open(resource [, mode [, options]])`
- `close`
- `read`
- `write(record)`
- `readStem(stem [, maximum])`
- `writeStem(stem [, maximum])`
- `position(recordNumber)`
- `recordNumber`
- `recordCount`
- `eof`
- `isOpen`
- `name`
- `ddName`
- `dataSetName`
- `memberName`
- `organization`
- `recordFormat`
- `logicalRecordLength`
- `blockSize`
- `isNativeRecordSet`

## Portable backend

One newline-delimited logical line is one record.  CRLF and LF inputs are accepted.  Delimiters are not part of record payload.  Portable records are semantic emulation, not an emulation of MVS allocation/catalog behavior.

## MVS backend

Initial native identities are DD names, sequential datasets, and PDS members.  Initial record formats are F, FB, V and VB.  The backend must expose logical records and native metadata while retaining dataset/DD allocation ownership semantics.

## EXECIO and source loading

RecordSet is intended as the reusable substrate for EXECIO-style DISKR/DISKW, stem/stack transfer, and MVS source loading from SYSEXEC/SYSPROC/dataset members.  Those consumers are layered above RecordSet rather than implemented as independent record I/O systems.

## MVS native driver boundary (v0.1-dev2)

The MVS implementation is split deliberately into two layers.

`RecordSetNativeMvs.c` owns portable RecordSet semantics which are still genuinely
MVS-specific: DD/dataset/member identity, allocation ownership, one-based logical
record position, FB/F padding policy, V/VB maximum-LRECL checks, metadata, and
rewind-and-skip positioning for sequential input.

`RecordSetMvsDriver.h` is the small native QSAM/DCB boundary.  Its read/write
operations exchange exactly one logical record per call.  A driver must remove
BDW/RDW information and block framing; RecordSet callers never see those bytes.

This split is normative.  The backend must not be reimplemented with a byte-stream
`fgets()`/newline emulation on MVS.
