# MySQL-wire live conformance

Usage:

    rexx mysql_wire_conformance.rex HOST PORT DATABASE USER EXECUTABLE TABLE [DISABLED_CAPABILITIES]

The dedicated table must contain at least:

    id INTEGER
    value INTEGER

The runner owns only row id `900001`.

Typical NoSQLServer invocation:

    rexx mysql_wire_conformance.rex \
      127.0.0.1 3333 nosqlserver '' /usr/bin/mariadb wire_core_probe \
      GENERATEDKEYS,TRANSACTIONTIMEOUT

Current live scenarios:

- basic query
- transaction commit + visibility
- rollback-before-commit
- prepared statement mutation
- mutation affected-row result
- generated keys are capability-gated and remain skipped unless the live table
  contract is explicitly extended for auto-generated IDs
