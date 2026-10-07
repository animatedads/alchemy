# RecordSet v0.1-dev4

This revision responds to the first live ED209Z MVS 3.8J run (RSQQUAL job 56).

Fixes:

- IFOX00 object output uses `SYSGO`, not `SYSLIN`.
- assembler option changed to `OBJECT,NODECK`.
- exported `ENTRY` declarations moved after their symbols are defined, matching Assembler XF requirements.
- `DCBD DSORG=QS` moved to the end of the module because it creates the `IHADCB` DSECT.
- `RSHNDL DSECT` is followed by an explicit `RSETQSAM CSECT` resume.
- each external entry establishes a local R12 base from its entry address and an R10 base for the common CSECT.
- R10 is reserved for common-CSECT addressability and is no longer used as an RQWRITE scratch register.
- dev4 JCL remains self-contained and targets IFOX00/IEWL on MVS 3.8J.

No QSAM record semantics were changed in this repair.
