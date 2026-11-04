# NoSQLServer v0.86 bulk result materialisation

## Contract

A bounded query result is one semantic result set.  Consumers must not be forced
to cross the backend boundary once per row and then traverse the same data again
merely to serialize it.

The shared result surface is:

```rexx
rs = db~query(sql)
rows = rs~asArray             -- existing Array, zero-copy
dirs = rs~asDirectories       -- one typed projection pass
jsonText = rs~asJson          -- one typed projection + one json.cls call
```

The same methods exist on `NoSQLDatabaseCoreQueryResult`.

## JSON type mapping

- NULL -> JSON null
- BOOLEAN -> JSON true / false
- INTEGER -> JSON number, exact lexical integer retained
- DECIMAL -> JSON number
- VARCHAR / TEXT -> JSON string, including numeric-looking text
- DATE / DATETIME -> JSON string
- BLOB -> JSON string representation owned by the backend
- GEOMETRY -> native `makeJSON` when available, otherwise JSON string
- UNKNOWN -> structured Array/Directory/Table retained; scalar fallback string

The JSON package is never asked to infer VARCHAR-vs-number or BOOLEAN-vs-0/1.

## Native backend producer rule

PostgreSQL/libpq, MySQL-compatible and future native providers should produce
the complete Array/object graph in one backend-owned pass.  They should not:

1. expose a native result;
2. make the consumer call a native accessor for every field;
3. create an intermediate DatabaseRow graph;
4. copy that graph again for JSON.

For PostgreSQL the desired bounded-result path is:

```text
PGresult* -> one producer materialisation pass -> Array<Directory/row objects>
          -> one json.cls serialization call
```

Very large results remain a separate cursor/streaming concern.

## Scope of this delivery

This package implements and qualifies the shared NoSQLServer/Database Core
consumer boundary.  The historical `oorexx_native_database_backends_v0.1.zip`
archive is not present in the active workspace, so this delivery does not claim
the libpq producer itself has been patched.  That producer should adopt this
contract as its next change.
