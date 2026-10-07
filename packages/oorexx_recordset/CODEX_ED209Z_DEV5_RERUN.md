# Codex — ED209Z RecordSet dev5 rerun

Run ONLY ED209Z in this pass.

Identity:
- access alias: `ed209c`
- actual Linux hostname observed: `test-us-east`
- Hercules config: `/home/azureuser/mvs-tk5/conf/tk5-ed209c.cnf`
- MVS guest: `ED209Z`
- ED209ZZ on ED209I is a different guest and MUST NOT be run yet.

Procedure:
1. Connect through the existing `sshnode.sh ed209c` route.
2. Confirm the active Hercules instance uses `tk5-ed209c.cnf`.
3. Do not IPL or alter Hercules/JES configuration.
4. Extract `oorexx_recordset_v0.1-dev5.zip`.
5. Submit the UNCHANGED job `tests/dev5/mvs/QUALIFY.JCL` through the same
   existing Hercules reader path used for jobs 56 and 57.
6. Preserve complete printer/JES output before changing anything.

Capture:
- JES job id
- ASM1 RC and object record count
- ASM2 RC and object record count
- LKED RC
- GO RC
- RSOUT first record
- every assembler diagnostic if either assembler is nonzero

Expected clean path:
- ASM1 RC=0
- ASM2 RC=0
- LKED RC=0 or 4
- GO RC=0
- RSOUT begins `ONE`

If ASM1 still fails, classify ASSEMBLY and preserve the listing verbatim.
Do not edit source/JCL during the first dev5 run.
Do NOT run ED209ZZ until explicitly instructed.
