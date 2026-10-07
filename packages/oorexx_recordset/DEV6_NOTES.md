# RecordSet v0.1-dev6

Authority: ED209Z live dev5 run, RSQQUAL job 58.

Observed dev5 result supplied by the Architect:
- ASM1 RC=8; 29 object records written.
- 11 remaining assembler diagnostics, all IFO228 relocatable displacement.
- dev3 ENTRY/missing-SYSGO and dev4 IFO209/IFO026 families are gone.
- ASM2/LKED/GO did not establish a runnable qualification result.
- ED209ZZ remains untouched.

## dev6 repair

Dev5 correctly established `USING RSHNDL,8`, but dynamic RecordSet-handle
fields were still written with explicit R8 addressing forms such as
`HDCB(8)`, `HMODE(8)`, `HDCB(length,8)` and `HDDNAME(8)`.

On Assembler XF those operands retain a relocatable DSECT displacement instead
of being resolved through the active USING.  dev6 removes the redundant
explicit R8 base and lets `USING RSHNDL,8` resolve all RSHNDL fields.

Examples:

    HMODE(8)                 -> HMODE
    HDCB(8)                  -> HDCB
    HDCB(INDCBLEN,8)         -> HDCB(INDCBLEN)
    HDDNAME(8)               -> HDDNAME

The DCB/IHADCB offset expressions remain unchanged.

The dev6 QUALIFY.JCL embeds the authoritative dev6 assembler source exactly.
ED209Z is the only permitted live rerun target until this deck passes there.
