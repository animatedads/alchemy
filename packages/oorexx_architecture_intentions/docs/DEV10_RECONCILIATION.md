# Architecture Intentions v0.1-dev10 GitHub reconciliation

The **complete** dev10 ZIP remains the delivered source artifact. GitHub currently contains earlier dev9 delta classes and the new dev10 NotNotes publication module/test; older dev8 implementation classes are not yet backfilled to this directory. Treat the repo path as **partial, not installable**, until source hashes are reconciled.

Static checks on the dev10 ZIP: package JSON and example JSON parsed (26 documents), shell runner syntax passed, all files match the SHA-256 inventory, and ZIP CRC check passed. Interpreter-based dev10 testing is **unavailable in this session**, because ooRexx 5.3.0 r13196 is not accessible here.

The new publication class does not claim to publish a NotNotes document, perform SSC resolution or activate a deployment. NotNotes engine source dev15 is independently archived in the user Library (SHA-256 `57a7d1b09234621f20c9de5dda312b4e38140b57cb87c45f7318e59730db4488`). Core source Git backfill remains in progress; do not use the incomplete NotNotes repo directory for builds.
