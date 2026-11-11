# v0.1-dev2 native dev18 qualifier

Consumes the already-accepted v0.1-dev1 source-edit plan, pinned to dev18 CLI Git blob 29a3ed15ea49ae062a3ae51052f7f3f1eb1fa2c0. Copies source to a disposable temp directory, applies the patch to that copy and executes four native ooRexx regressions. Does not change real NotNotes state or bypass signing. Missing required source or interpreter is NOT_RUN (rc69).

This tests UI consumption, not a full 954/983-document cold start, live indexed SQLite, WAL, migration or Foreign Runtime/Crypto; those are separate release gates.
