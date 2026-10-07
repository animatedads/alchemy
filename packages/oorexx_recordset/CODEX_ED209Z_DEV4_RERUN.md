# Codex — RecordSet dev4 ED209Z rerun

Target only this machine for this pass:

    Linux access alias: ed209c
    observed Linux hostname: test-us-east
    Hercules config: /home/azureuser/mvs-tk5/conf/tk5-ed209c.cnf
    MVS guest: ED209Z

Do NOT run ED209ZZ yet.

The first unchanged dev3 run was RSQQUAL job 56 and failed in ASM1 RC=16.
That evidence is preserved under `evidence/recordset_dev3_ED209Z_20261007/result.txt`.

Use the replacement job:

    tests/dev4/mvs/QUALIFY.JCL

Submit it unchanged through the same existing Hercules reader path used for job 56.
Do not IPL, alter Hercules/JES, or edit system libraries.

Capture the complete JES printer output before changing source, regardless of result.
Save it as:

    evidence/recordset_dev4_ED209Z_20261007/recordset_dev4_ED209Z_QUALIFY.txt

and write `result.txt` with:

    guest=ED209Z
    host_alias=ED209C
    host_reported_hostname=test-us-east
    hercules_config=/home/azureuser/mvs-tk5/conf/tk5-ed209c.cnf
    job_name=RSQQUAL
    job_id=<actual>
    asm1_rc=<actual>
    asm2_rc=<actual>
    link_rc=<actual>
    go_rc=<actual or NOT_RUN>
    rsout_first_record=<actual or NOT_PRODUCED>
    result=PASS|FAIL
    failure_class=<ASSEMBLY|LINK|OPEN/DD|GET|REWIND|PUT|CLOSE|RECORD_FORMAT|OTHER_RUNTIME>

Pass requires both assembler steps to produce object decks, link to complete, GO RC=0,
and printed RSOUT to contain a record beginning `ONE`.

Important: do not infer failure from a non-zero assembler warning RC alone; preserve and report
the actual diagnostics and whether usable object output was produced.
