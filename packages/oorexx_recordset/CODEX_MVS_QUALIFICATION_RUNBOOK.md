# HISTORICAL DEV3 RUNBOOK

For dev4 use `CODEX_ED209Z_DEV4_RERUN.md`. The dev3 first run is preserved as evidence.

# Codex Runbook — ooRexx RecordSet MVS Qualification

## Read this first

There are TWO separate Hercules MVS machines.

| MVS guest | Linux host | Meaning |
|---|---|---|
| `ED209Z` | `ED209C` | FIRST qualification target |
| `ED209ZZ` | `ED209I` | SECOND independent qualification target |

Do **not** treat `ED209Z` and `ED209ZZ` as aliases.

Do **not** submit to both at once.

Do **not** change Hercules configuration, IPL either guest, alter JES, or change
system libraries as part of this qualification.

Qualify **ED209Z on ED209C first**.  Only after that result is captured should
the identical job be run on **ED209ZZ on ED209I**.

The qualification JCL is:

    tests/dev3/mvs/QUALIFY.JCL

This job is self-contained.  It embeds the RecordSet QSAM assembler modules
needed by the qualification.

---

# Phase 1 — ED209Z only

## 1. Work on the correct Linux host

Target:

    Linux host: ED209C
    MVS guest:  ED209Z

Before doing anything else, print or record:

    hostname
    pwd

The hostname must identify **ED209C**.

If it does not, STOP.  Do not guess.

## 2. Locate the RecordSet delivery

Use the supplied RecordSet dev3 delivery.

Expected package name:

    oorexx_recordset_v0.1-dev3.zip

Expected qualification member inside the extracted tree:

    tests/dev3/mvs/QUALIFY.JCL

Do not edit the assembler source or qualification JCL before the first run.

## 3. Inspect the JCL before submission

Read `tests/dev3/mvs/QUALIFY.JCL`.

Confirm that it contains steps that:

1. assemble the supplied RecordSet QSAM module with `IFOX00`;
2. link-edit the qualification program with `IEWL`;
3. execute the program;
4. use the supplied `RSIN` and `RSOUT` DD definitions;
5. print/display the resulting output.

This is an inspection only.  Do not "modernize" the JCL.

The target is MVS 3.8J.

Do not add `AMODE` / `RMODE` statements or later-z/OS conveniences.

## 4. Submit the job using the EXISTING ED209Z submission method

Use the submission mechanism that is already established for ED209Z.

Examples might be an existing Hercules card reader path, an existing submit
script, or TSO/JES submission.  Use whichever mechanism is already used for
other ED209Z jobs.

Do not invent a new submission path if one already exists.

If the submission mechanism is not immediately obvious, locate the existing
ED209Z job-run scripts or operator notes on ED209C and use those.

Do not alter Hercules networking or system configuration merely to submit this
job.

## 5. Wait for the job to finish

Capture the JES job identifier.

Collect the COMPLETE output for every step, not just the final line.

The evidence must include:

- assembler step return code;
- link-edit step return code;
- GO/execution step return code;
- assembler diagnostics, if any;
- linker diagnostics, if any;
- program output;
- printed `RSOUT` contents.

## 6. Pass criteria

The intended successful result is:

    assembler RC acceptable for a clean build
    link-edit RC acceptable for a clean link
    GO RC = 0

The produced output dataset must contain a record beginning:

    ONE

Do not report PASS merely because the job entered JES.

Do not report PASS merely because assembly succeeded.

Do not report PASS without the execution result and resulting record output.

## 7. Preserve the ED209Z evidence

Save the complete JES output without editing it.

Suggested name:

    recordset_dev3_ED209Z_QUALIFY.txt

Also create a short result note containing:

    guest=ED209Z
    host=ED209C
    job_id=<actual JES job id>
    assembler_rc=<actual>
    link_rc=<actual>
    go_rc=<actual>
    rsout_first_record=<actual>
    result=PASS|FAIL

If there is a failure, preserve all diagnostics verbatim.

Do not "fix" the source before recording the first failure.

---

# Phase 2 — ED209ZZ only

Run this phase only after Phase 1 evidence has been captured.

Target:

    Linux host: ED209I
    MVS guest:  ED209ZZ

Repeat the same qualification job unchanged.

Before submission record:

    hostname
    pwd

The hostname must identify **ED209I**.

If it does not, STOP.

Use:

    tests/dev3/mvs/QUALIFY.JCL

Do not substitute ED209Z files, spool output, or job IDs.

Submit using the EXISTING ED209ZZ submission mechanism.

Capture the same evidence and save it separately as:

    recordset_dev3_ED209ZZ_QUALIFY.txt

Create a result note:

    guest=ED209ZZ
    host=ED209I
    job_id=<actual JES job id>
    assembler_rc=<actual>
    link_rc=<actual>
    go_rc=<actual>
    rsout_first_record=<actual>
    result=PASS|FAIL

---

# What Codex must NOT do

- Do not confuse `ED209Z` with `ED209ZZ`.
- Do not assume both guests live on ED209C.
- Do not assume both guests live on ED209I.
- Do not run both qualifications in parallel.
- Do not IPL either machine.
- Do not change Hercules configuration.
- Do not change JES configuration.
- Do not replace QSAM record I/O with POSIX-style byte I/O.
- Do not rewrite the test to use Unix files.
- Do not add later-MVS or z/OS assembler directives.
- Do not claim MVS qualification without JES execution evidence.
- Do not discard failing spool output.
- Do not modify the qualification source before preserving the first result.

---

# If the job fails

Classify the failure before changing anything.

Use these categories:

    ASSEMBLY
    LINK
    OPEN/DD
    GET
    REWIND
    PUT
    CLOSE
    RECORD_FORMAT
    OTHER_RUNTIME

Report:

1. exact failing job step;
2. exact return code;
3. exact assembler/linker/runtime message;
4. relevant spool lines;
5. whether failure occurred on ED209Z, ED209ZZ, or both.

Do not make speculative source changes until this evidence is recorded.

---

# Required final Codex report

Return one block for each machine.

Example shape:

    RECORDSET MVS QUALIFICATION

    ED209Z
      host: ED209C
      job id: ...
      assemble rc: ...
      link rc: ...
      go rc: ...
      RSOUT first record: ...
      result: PASS/FAIL
      evidence file: ...

    ED209ZZ
      host: ED209I
      job id: ...
      assemble rc: ...
      link rc: ...
      go rc: ...
      RSOUT first record: ...
      result: PASS/FAIL
      evidence file: ...

Do not merge the two machines into one result.

---

# Short prompt to give Codex

You are qualifying the ooRexx RecordSet dev3 QSAM backend on two SEPARATE
MVS 3.8J Hercules guests.

FIRST:
    ED209Z is the MVS guest on Linux host ED209C.

SECOND:
    ED209ZZ is the MVS guest on Linux host ED209I.

Do ED209Z first and capture complete JES evidence before touching ED209ZZ.

Use the unmodified job:
    tests/dev3/mvs/QUALIFY.JCL

On each host, verify `hostname` before submission.  Use that machine's existing
JES/card-reader/submit mechanism.  Do not IPL, change Hercules/JES
configuration, or invent a new submission path.

Capture assembler RC, IEWL RC, GO RC, complete diagnostics, and RSOUT.
GO must return RC=0 and RSOUT must contain a record beginning `ONE`.

Save separate evidence files for ED209Z and ED209ZZ and report the two results
separately.  If anything fails, preserve the first failing spool output before
making changes.
