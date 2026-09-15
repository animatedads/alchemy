# IBM 4361 v0.3 recovery checkpoint 2

This tree is an intermediate recovery drop after a transient working-directory loss.
It is intentionally delivered before the full previously reached v0.3 supervisor/console state has been reconstructed.

Recovered and executable now:

- external shared-library references only; no vendored Alchemy/Crypto/msqlshim payloads;
- read-only Hercules CCKD media parser with cached CKD records;
- real IBM3330 device nucleus for Read IPL, Read Data, Seek, Search ID Equal, Sense and NOP;
- format-0 CCW byte 5 retained as opaque/ignored rather than rejected;
- channel Status Modifier skip semantics;
- Jay Maynard MVTRES.350 real-media IPL acceptance: final IPL PSW `0000000000000080`, IA `000080`.

Not yet reconstructed in this recovery tree:

- the later demand-driven S/370 executor/opcode set;
- the complete 3330 command surface previously reached by MVT;
- 3215 guest console and the separate 4361 physical operator console;
- v5/v7 extended checkpoint codecs, pending I/O interrupts and later MVT/SVCLIB replay checkpoints.

Recovery rule from this point: every meaningful green architectural boundary is packaged to `/mnt/data` immediately with SHA-256 before continuing.


## Journal integration added to this recovery base

The optional `IBM4361Journal.cls` adapter has been added without changing the durable freeze-file format.  Journal-pointed state is a separate live debugging/recovery facility.  New regressions cover range-delta RAM branching, whole-instruction rewind, live method patch + rewind, and byte-identical durable freeze output with journal history present.

The current recovery2 channel codec still lacks pending-interrupt reconstruction; the journal adapter fails closed on that state until the later v7 channel model is recovered.
