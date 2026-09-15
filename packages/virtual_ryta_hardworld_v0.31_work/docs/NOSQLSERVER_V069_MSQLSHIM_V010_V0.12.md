# v0.12 — NoSQLServer v0.69 and msqlshim v0.10 platform contract

## Purpose

v0.12 moves the Algorithm Relation integration baseline from NoSQLServer v0.68 / msqlshim v0.08 to the supplied NoSQLServer v0.69 / msqlshim v0.10 without changing HardWorld semantics.

## NoSQLServer v0.69

v0.69 adds the concrete Database Core v0.34 relational-source/table-source compatibility shape.  An Algorithm Relation external engine remains an ordinary federated external engine.

### Host class-set boundary

The adapter must not resolve NoSQLServer transport classes by global public names.  The host package supplies:

```text
TABLE_DEFINITION
TABLE_METADATA
DATABASE_ROW
DATABASE_RESULT
```

This matters because v0.69 explicitly documents overlapping historical class names between NoSQLServer and Database Core packages.  Observable contract compatibility does not imply global class identity.

Missing class-set entries are a bind-time error and do not execute the algorithm provider.

### Database Core facade invariant

The v0.34 facade is metadata-only until row demand:

```text
relationalSource~tables     observational
relationalSource~table      observational
tableSource~metadata        observational
tableSource~describe        observational

tableSource~rows            may materialise once
tableSource~query           operates on the same materialisation
```

The reference RYTA provider exposes two relations and remains at one provider execution while both are read.

## msqlshim v0.10

v0.10 adds binary prepared statements and read-only server cursors.  This creates a new execution boundary worth stating explicitly.

### Prepared-statement phases

```text
COM_STMT_PREPARE
    parse / parameter count / result metadata
    MUST NOT execute Algorithm Relation

COM_STMT_EXECUTE CURSOR_TYPE_READ_ONLY
    executes native query through normal backend gate
    MAY cross Algorithm Relation materialisation boundary once
    stores materialised native result in connection/statement cursor state

COM_STMT_FETCH
    reads only cursor state
    MUST NOT re-enter NoSQLServer query execution
    MUST NOT re-enter Algorithm Relation provider
```

Reset and re-execute rebuild the protocol cursor from the same already-materialised Algorithm Relation unless the Algorithm Relation engine itself has been explicitly given a fresh logical execution identity.

### Multi-relation provider

Preparing both `ryta_actions` and `ryta_trace` leaves provider invocation count at zero.  Executing/fetching both prepared cursors produces one underlying RYTA provider execution total.

## No new authority

Database Core and msqlshim transports do not gain authority semantics.  Values such as `REQUIRED`, `PROHIBITED`, target scores, confidence or lexical evidence remain data at these layers.

## Current safe optimizer boundary

Still safe:

```text
metadata/catalog discovery
post-materialisation filters
projection
ORDER BY
LIMIT
joins
aggregates
prepared cursor fetch
```

Not admitted in v0.12:

```text
provider predicate pushdown
provider cardinality probing by execution
SELECT-triggered external side effects
prepared FETCH reopening the provider
implicit fresh execution on protocol cursor reset
```
