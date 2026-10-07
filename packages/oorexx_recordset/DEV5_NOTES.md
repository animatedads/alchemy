# RecordSet v0.1-dev5

Authority: first dev4 live run on ED209Z, RSQQUAL job 57.

Dev4 live result:
- ASM1 RC=8, 29 object records produced.
- ENTRY and missing-SYSGO defects from dev3 were gone.
- remaining errors: IFO209 addressability, IFO228 relocatable displacement,
  and IFO026 continuation-card parsing.
- ASM2 and GO did not run.

Dev5 repairs:
1. Establish `USING RSHNDL,8` whenever R8 becomes a RecordSet QSAM handle.
2. Shorten all assembler source cards to <= 71 columns. In dev4, comment
   trailing `*` characters landed in column 72 and became continuation marks.
3. Regenerate ASM1 in QUALIFY.JCL directly from RecordSetMvsQsam.asm.
4. Gate LKED on both ASM1 and ASM2 to suppress secondary missing-object noise.

ED209ZZ remains intentionally untouched until ED209Z passes.
