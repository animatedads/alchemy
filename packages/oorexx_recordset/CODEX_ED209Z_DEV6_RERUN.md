# Codex — RecordSet dev6 ED209Z rerun

Run **ED209Z only**.

Identity:

    access alias: ed209c
    expected Hercules guest: ED209Z
    observed Linux hostname may be: test-us-east
    Hercules config: /home/azureuser/mvs-tk5/conf/tk5-ed209c.cnf

Do not run ED209ZZ.  ED209ZZ is a different guest on ED209I.

## Job

Use the dev6 package unchanged and submit:

    tests/dev6/mvs/QUALIFY.JCL

through the same existing Hercules reader path used for RSQQUAL jobs 56, 57,
and 58.

Before submission, verify the running guest through c3270 / TSO as before.
Do not IPL MVS and do not alter Hercules, JES, SYS1.MACLIB, SYS1.AMODGEN, or
reader configuration.

## Evidence to capture

Preserve complete printer/JES output before changing anything.  Report:

    guest=ED209Z
    job_name=RSQQUAL
    job_id=<actual>
    asm1_rc=<actual>
    asm1_object_records=<actual>
    asm2_rc=<actual>
    asm2_object_records=<actual>
    link_rc=<actual>
    go_rc=<actual>
    rsout_first_record=<actual or NOT_PRODUCED>
    result=PASS|FAIL
    failure_class=<if failed>

For assembler failure, include every IFOX diagnostic code and statement number.

## Expected progression

dev6 specifically targets the 11 IFO228 relocatable-displacement errors left
by dev5.  The following older families must remain absent:

    IFO189 invalid ENTRY
    IFO256 missing SYSGO
    IFO209 addressability
    IFO026 continuation-card

A successful full qualification requires:

    ASM1 RC=0
    ASM2 RC=0
    LKED RC=0 or 4
    GO RC=0
    printed RSOUT contains a record beginning ONE

Do not call the result PASS merely because ASM1 succeeds.
Do not run ED209ZZ until the ED209Z evidence has been reviewed.
