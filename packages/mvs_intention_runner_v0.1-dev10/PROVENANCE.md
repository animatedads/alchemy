# MVS Intention Runner v0.1-dev10 — repository candidate

Artifact SHA-256: `c7c424e6e12a8b5db2ef1ac7c7813309e70b6f53827944089e57a71f958bfd5b`.

dev10 preserves dev9's authority split and adds two independent upgrades:

- current Terminal Machine source target: v0.22-candidate13, reported artifact SHA-256 `6992ae5206d697aeba887eaeb36f108df6f9fd0c0e01f47c96ae827c3f7d329d`;
- MVS Alchemy PRE23 JES completion gate: facility PASS is insufficient until HASP395 and retained final spool are observed.

Executed in the authoring environment:
- PRE23 `check_maslive_jes_completion.py` PASS;
- package shell syntax PASS;
- static dev10 completion-gate/source contract PASS.

Not claimed here:
- ooRexx r13196 execution of dev10;
- candidate13 focused compatibility execution;
- candidate13 s3270 reference regression under r13196;
- live ED209Z/ED209ZZ qualification;
- live PRE23 qualification.

Embedded Intention Service source is omitted from the repository candidate because Alchemy carries it as a first-class dependency.
