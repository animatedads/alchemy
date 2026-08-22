# Algorithm Relation prepared-cursor probe v0.1

A narrow integration harness for the supplied:

- Virtual RYTA / HardWorld v0.11
- msqlshim v0.10
- NoSQLServer v0.69

It proves that MySQL classic prepared-cursor traffic can cross the lazy
Algorithm Relation boundary without turning metadata discovery, cursor FETCH,
second-relation access, RESET, or re-EXECUTE into additional algorithm runs.

The harness deliberately does **not** modify msqlshim or NoSQLServer.

## v0.69 compatibility repair exposed by the probe

The supplied v0.11 `NoSQLServerAlgorithmRelationExternalEngine.cls` constructs
`.DatabaseTableMetadata` by global package name in `tableMetadata()`.  When the
adapter and NoSQLServer are loaded as separate packages this fails with:

    Object ".DATABASETABLEMETADATA" does not understand message "NEW"

The probe carries a minimal compatibility copy of that adapter method.  It
obtains `TABLE_METADATA` from the same injected NoSQL class set already used
for `TABLE_DEFINITION`, `DATABASE_ROW`, and `DATABASE_RESULT`.  The test server
supplies `.DatabaseTableMetadata` from the NoSQLServer host package.

This keeps PREPARE metadata observational: the RYTA provider invocation count
remains zero until COM_STMT_EXECUTE demands rows.

## Run

    ./run.sh /path/to/virtual_ryta_hardworld_v0.11 \
             /path/to/msqlshim_v0.10 \
             /path/to/nosqlserver_v0.69/src/NoSQLServer.cls \
             3684

The script creates only a temporary database/work tree.
