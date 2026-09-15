# msqlshim v0.21.2

## v0.21.2 — identity/provenance consistency repair

v0.21.2 preserves the v0.21.1 DEFLATE arithmetic-precision fix and repairs a split package identity discovered by the full package suite: the compatibility snapshot identified v0.21.1 while Alchemy metadata and `@@msqlshim_version` still identified v0.20. All public identity/evidence surfaces now report v0.21.2. No protocol or backend semantics are changed.


## v0.20 — Alchemy Objects v0.8 / NoSQLServer v0.79 reconciliation

v0.20 takes v0.19 as the wire-protocol parent. It preserves connection
attributes, handshake database selection, query attributes, modern result
metadata, compression, prepared statements/cursors, typed binary parameters,
fair backend scheduling and the deterministic per-client fixture discipline.

The dependency boundary remains package-reference only: **NoSQLServer source is
not embedded in msqlshim**. The validated companions are `nosqlserver_v0.79`,
`alchemy_objects_v0.8`, and `oorexx_crypto_v0.1`.

`MySQLWireServer`, `MySQLBackendGate`, and `MySQLWireConnection` now enter the
Alchemy base through the preferred `INIT:SUPER` construction chain and satisfy
`AlchemyAdoptionVerifier` at `STANDARD`. A server configured with a sealer /
capability authority propagates those optional services into its scheduler and
per-connection service objects. This still does not confer authentication,
database, network, or SQL authority.

The standalone launcher also retains the optional TUTOR hook:

```text
rexx mysql_wire_server.rex DATABASE_ROOT PORT HOST [TUTOR_ROOT]
```

Omitting `TUTOR_ROOT` preserves classic behaviour. Supplying it only enables
NoSQLServer's already-explicit Unicode capability; tables/columns must still opt
into `textMode: UNICODE`.

See `DEPENDENCIES.md` and `VALIDATION.txt`.

---

# msqlshim v0.19

`msqlshim` is the isolated MySQL/MariaDB wire-protocol lane for NoSQLServer. It does not modify NoSQLServer's SQL parser, storage engine, or public API. MySQL-family protocol/session compatibility lives here; native SQL semantics remain in NoSQLServer.

## v0.21 — reconciled v0.20 lines

v0.21 uses the NoSQLServer v0.79 / Alchemy Objects v0.8 reconciliation branch as its structural parent and merges the independently-developed process-list branch onto it. It retains preferred `INIT:SUPER` Alchemy construction, sealer/capability-authority propagation, optional external `TUTOR_ROOT`, and the strict package-reference-only NoSQLServer boundary.

The active-session catalogue now implements `SHOW PROCESSLIST`, `SHOW FULL PROCESSLIST`, and classic `COM_PROCESS_INFO`. `Threads_connected` and cumulative `Connections` come from the same registry. Process-list `Info` is deliberately blank: msqlshim does not retain SQL text, parameter values, row contents, or authentication bytes merely for observability.

No `NoSQLServer.cls` or `vendor/` tree is permitted inside this package.

## v0.19 — connection handshake attributes and database selection

v0.19 keeps the v0.18 package-reference dependency boundary: **NoSQLServer source is not embedded in msqlshim**. The tested companion remains `nosqlserver_v0.77`, resolved only through `REXX_PATH`, alongside package references to `alchemy_objects_v0.5` and `oorexx_crypto_v0.1`.

The protocol change is `CLIENT_CONNECT_ATTRS` support and a real parser for the MySQL 4.1 handshake response. The shim now records the connection-local client user, max-packet declaration, character set, requested authentication plugin, requested initial database, and length-encoded connection attributes without copying attribute values into Alchemy telemetry. If `CLIENT_CONNECT_WITH_DB` is negotiated, the requested database now becomes the session database before the first command. Malformed or truncated connection-attribute blocks are rejected during the handshake instead of being silently ignored.

The compatibility snapshot now declares `client_connect_attrs` and `handshake_database_selection`. Authentication remains deliberately unvalidated and TLS remains unadvertised; parsing handshake identity/attributes is not treated as authentication authority.

For development or manual execution, point the test runner at the package roots:

```bash
NOSQLSERVER_ROOT=/path/to/nosqlserver_v0.77 \
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.5 \
OOREXX_CRYPTO_ROOT=/path/to/oorexx_crypto_v0.1 \
./run_tests.sh
```

`tests/dependency_boundary_smoke.sh` continues to fail if a `NoSQLServer.cls` is copied into the shim or if a `vendor/` directory reappears.

## v0.17 — truthful wire identity + repeatable prepared regression

v0.17 keeps the v0.16 AlchemyObject service foundation and canonical NoSQLServer v0.75 backend, while making the component/backend identity visible to ordinary MySQL clients. The curated system-variable surface now includes `@@msqlshim_version`, `@@nosqlserver_release`, `@@nosqlserver_sql_level`, and `@@alchemy_object_version`; the same names are discoverable through `SHOW VARIABLES`. These are identity/evidence values only and do not imply extra SQL, security, or protocol authority.

The long-running prepared-statement regression now allocates unique fixture identifiers per process/run rather than reusing historical fixed IDs. This removes false duplicate-row failures when a demo database has accumulated prior validation rows, and allows the full prepared/cursor/typed-parameter path to return to the package acceptance suite.

## v0.16 — Alchemy service-object foundation

v0.16 adopts Alchemy Objects v0.4.3 for the identity/lifecycle-bearing wire service, per-connection session object, and FIFO backend scheduler. It deliberately does **not** turn packet values, SQL rows, or helper values into heavyweight base objects.

`MySQLWireServer~compatibilitySnapshot` is a bounded machine-readable statement of the protocol surface. It reports zlib compression, deprecated-EOF framing, optional metadata framing, query attributes, prepared statements and read-only prepared cursors as present, while reporting TLS, authentication and zstd as absent. Alchemy telemetry records operation counts/timings and detached relationships; it does not record SQL text, parameter values, row bodies, or authentication bytes.

The normal constructor remains compatible:

```rexx
server = .MySQLWireServer~new(databaseRoot, host, port)
```

A host that already owns an Alchemy evidence sealer/capability authority may additionally pass them as fourth/fifth arguments to enable sealed service introspection. This does not grant database or network authority.

For deterministic project-root execution, the package carries the exact required Alchemy v0.4.3 runtime closure plus exact `crypto.cls` from oorexx_crypto v0.1. See `ALCHEMY_RUNTIME_PROVENANCE.md`.


## v0.15 query attributes

v0.15 adds classic-protocol `CLIENT_QUERY_ATTRIBUTES` support (capability bit 27).
When negotiated, `COM_QUERY` accepts the MySQL binary parameter/attribute prefix,
including `parameter_count`, the single supported parameter set, NULL bitmap,
per-value type/unsigned metadata, length-encoded names, and binary values.  Values
needed by positional `?` placeholders are bound through NoSQLServer's existing
`DatabaseParameterBinder`; remaining named values stay transport metadata and are
not promoted into SQL authority.

`COM_STMT_EXECUTE` also accepts `PARAMETER_COUNT_AVAILABLE` and a supplied count
larger than the prepared placeholder count.  The prepared placeholders consume the
first values; additional named values are decoded as query attributes without
changing statement semantics.  Existing clients that do not negotiate
`CLIENT_QUERY_ATTRIBUTES` retain the v0.14 packet layout unchanged.

The regression `tests/mysql_wire_query_attributes_client.py` proves:

- handshake advertisement of `CLIENT_QUERY_ATTRIBUTES`;
- `COM_QUERY` with one positional parameter plus a named `traceparent` attribute;
- zero-attribute `COM_QUERY` framing; and
- `COM_STMT_EXECUTE` with one prepared parameter plus one extra named attribute.

## Concurrency model

Each TCP client has independent MySQL protocol state, including compression buffers and packet sequences. The shim keeps one shared NoSQLServer `FileDatabaseEngine` so it does not silently weaken the backend's mutation/isolation contract.

`v0.08` adds a FIFO backend ticket gate in front of ordinary SQL execution. This prevents a sustained writer from repeatedly reacquiring the guarded ooRexx engine ahead of a reader that is already waiting. The ticket is released before result-set encoding and socket output, so a slow or blocked client cannot retain the backend execution slot merely because it is not reading quickly.

This is scheduling fairness, not parallel database execution. Multiple clients may perform protocol work concurrently, but native SQL execution remains serialized through the single backend engine until NoSQLServer explicitly exposes a stronger concurrent-engine contract.

## Current compatibility surface

Protocol support includes protocol-10 handshake, unauthenticated protocol sessions, `COM_QUERY`, `COM_INIT_DB`, `COM_PING`, `COM_QUIT`, text-protocol result sets, OK/ERR/EOF packets, and basic MySQL column metadata.

`v0.14` also advertises and implements `CLIENT_DEPRECATE_EOF` and `CLIENT_OPTIONAL_RESULTSET_METADATA`. Clients requesting EOF deprecation receive no metadata EOF separator and get the documented OK-style `0xFE` result terminator. Clients requesting optional result-set metadata receive the `metadata_follows` byte; this release deliberately sends `RESULTSET_METADATA_FULL` rather than suppressing field descriptions. Legacy clients that do not request either capability retain the previous packet shape.

Shim-native MySQL compatibility commands include:

```sql
SET ...;
USE ...;
SELECT VERSION();
SELECT DATABASE();
SELECT @@version;
SELECT @@version_comment;
SELECT @@sql_mode;
SELECT @@character_set_client;
SELECT @@character_set_connection;
SELECT @@character_set_results;
SELECT @@autocommit;
SELECT @@max_allowed_packet;
SHOW DATABASES;
SHOW TABLES;
SHOW FULL TABLES;
DESCRIBE table_name;
DESC table_name;
SHOW COLUMNS FROM table_name;
SHOW FULL COLUMNS FROM table_name;
SHOW VARIABLES;
SHOW VARIABLES LIKE 'pattern';
SHOW STATUS;
SHOW STATUS LIKE 'pattern';
```

`SHOW SESSION/GLOBAL VARIABLES` and `SHOW SESSION/GLOBAL STATUS` spellings are also accepted. `LIKE` supports `%` and `_` wildcards for the shim's curated variable/status surface.

The session variable values describe the msqlshim compatibility personality. `SHOW STATUS` deliberately exposes only a small shim-oriented compatibility set and must not be interpreted as NoSQLServer operational telemetry.

`SET NAMES utf8mb4` and other connector bootstrap `SET ...` statements remain harmlessly accepted. This release does not claim full MySQL session-variable mutation semantics.

A `SELECT * FROM <single-table> ...` query is given an explicit result schema from NoSQLServer table metadata before execution. Zero-column SELECT results are rejected with an ERR packet rather than being emitted as malformed MySQL packets.

## Metadata boundary

`DESCRIBE` / `SHOW COLUMNS` are resolved through NoSQLServer's existing `databaseCore~tableMetadata()` facade. `Key` and `Extra` remain blank and `Default` is NULL where the backend does not expose those facts; the shim does not invent them.

Unknown tables return MySQL error 1146 / SQLSTATE `42S02`.

## Execution-path rule

ooRexx resolves `::requires` from the initial execution working path. Run all commands from the msqlshim project root. The root-relative require chain is intentional:

```text
mysql_wire_server.rex -> src/MySQLWireServer.cls -> NoSQLServer.cls (resolved from NOSQLSERVER_ROOT/src)
tests/mysql_wire_smoke.rex -> src/MySQLWireServer.cls -> NoSQLServer.cls (resolved from NOSQLSERVER_ROOT/src)
```

Run the smoke as:

```bash
rexx tests/mysql_wire_smoke.rex
```

The default demo database path is `example/demo`.

## v0.05 validation focus

The live ooRexx socket smoke now covers connector bootstrap probes in addition to the earlier handshake, metadata, mutation and result-set tests:

```text
SELECT @@version
SELECT @@sql_mode
SET NAMES utf8mb4
SHOW VARIABLES LIKE 'character_set_%'
SHOW STATUS LIKE 'Ssl_cipher'
```

The current v0.16 package vendors canonical NoSQLServer v0.75. GeoPackage support remains part of that class, including the native ooRexx SQLite/GeoPackage reader introduced in v0.74; fixtures and storage-provider tests remain owned by the canonical NoSQLServer package rather than being duplicated into msqlshim.


## v0.05 concurrency repair

Socket read/write helpers are unguarded so an idle authenticated client cannot hold the MySQLWireServer object guard while blocked in recv() and thereby stall another client during authentication. `tests/mysql_wire_multiclient_smoke.rex` keeps one client idle while authenticating and pinging a second client.

## v0.06 protocol coverage

v0.06 widens the actual MySQL TCP protocol surface rather than teaching
NoSQLServer MySQL-specific SQL.

The listener now advertises `CLIENT_COMPRESS`.  Compression follows the classic
MySQL compressed-packet layer: the normal 4-byte MySQL packet stream is wrapped
inside 7-byte compressed frames after the connection-phase OK packet.  Incoming
zlib streams are decoded natively in ooRexx, including dynamic-Huffman DEFLATE;
no external zlib process is used.

Useful client probes include:

    mysql --compress -h 127.0.0.1 -P 3333

and, once connected:

    SHOW STATUS LIKE 'Compression';
    SHOW STATUS LIKE 'Compression_algorithm';
    SHOW VARIABLES LIKE 'protocol_compression_algorithms';

Utility commands used by connectors and older client APIs are also implemented:
`COM_FIELD_LIST`, `COM_STATISTICS`, `COM_DEBUG`, `COM_SET_OPTION`, and
`COM_RESET_CONNECTION`.

v0.10 extends the prepared-statement binary protocol with read-only server cursors as described below. TLS and real
account authentication remain deliberately unadvertised until they are genuine.


## v0.07 mixed-client concurrency

The server object is a dispatcher, not a connection lock. All request-path methods are explicitly `unguarded`; connection-local mutable state lives on `MySQLWireConnection`. A compressed client that is executing a long query or blocked by TCP backpressure while returning a large result must not serialize unrelated clients.

Compression is negotiated per connection during the handshake. It is therefore valid to run these at the same time:

```bash
mysql --compress -h 127.0.0.1 -P 3333
mysql -h 127.0.0.1 -P 3333
```

One connection remains compressed for its lifetime and the other remains uncompressed. `msqlshim` does not invent a non-standard mid-connection compression toggle.

Regression:

```bash
python3 tests/mysql_wire_mixed_concurrency.py
```

The test deliberately leaves a large compressed result unread until server `send()` backpressure occurs, then proves that a second uncompressed client can still connect and execute `SELECT @@version`.


## v0.13 prepared binary value coverage

v0.13 keeps the canonical NoSQLServer v0.74 backend snapshot from v0.12 and widens only the MySQL prepared-statement decoder. `COM_STMT_EXECUTE` now accepts classic binary parameter encodings for `MYSQL_TYPE_FLOAT`, `MYSQL_TYPE_DOUBLE`, `MYSQL_TYPE_DATE`, `MYSQL_TYPE_DATETIME`, `MYSQL_TYPE_TIMESTAMP`, `MYSQL_TYPE_TIME`, and `MYSQL_TYPE_YEAR` in addition to the integer/string/decimal/BLOB families already supported.

The decoder is native ooRexx. IEEE-754 FLOAT/DOUBLE payloads are decoded from the wire representation without an external helper. Finite values enter NoSQLServer as DECIMAL values; NaN/Infinity fail explicitly. MySQL binary temporal payloads are canonicalized before the existing NoSQLServer parameter binder is invoked. DATE and DATETIME/TIMESTAMP use the corresponding common database values; TIME remains canonical text because NoSQLServer's current common type vocabulary has no TIME type.

Regression `tests/mysql_wire_prepared_client.py` now round-trips FLOAT and DOUBLE through the `telemetry.reading` DECIMAL column and verifies DATE, DATETIME and multi-day TIME parameter text through ordinary NoSQLServer storage, while retaining prepared cursor/fetch coverage.

## v0.12 backend refresh

v0.12 keeps the v0.10 MySQL protocol/session surface and v0.11 backend-snapshot discipline unchanged, while refreshing the self-contained vendored backend from canonical NoSQLServer v0.73 to canonical NoSQLServer v0.74. `vendor/NoSQLServer.cls` is copied byte-for-byte; msqlshim does not own or modify SQL, federation, GeoPackage, JSON, or SQLite semantics.

The refresh carries forward the complete v0.73 JSON/general-JOIN surface and adds the v0.74 native ooRexx SQLite/GeoPackage reader (`SQLiteNativeDatabase`, `SQLiteDatabaseEngine`, `SQLITE_NATIVE_BINARY_READ`, `SQLITE_NATIVE_RELATION_PROVIDER`). GeoPackage typed geometry/subtype/SRID behavior remains present. The old C GeoPackage bridge is no longer part of canonical NoSQLServer v0.74 and is therefore not expected in msqlshim either.

Regression `tests/v012_backend_snapshot_smoke.rex` pins release/SQL level 0.74 and asserts the bundled backend exports GeoPackage, JSON, native SQLite relation, and native SQLite binary-reader classes.

## v0.11 backend refresh

v0.11 keeps the v0.10 MySQL protocol/session implementation unchanged and refreshes the self-contained vendored backend from NoSQLServer v0.58 to canonical NoSQLServer v0.73. The vendor file is copied byte-for-byte; no MySQL-specific behavior is pushed into NoSQLServer.

The refresh brings the shim's default bundled backend up to the current SQL/federation surface, including the v0.72 general INNER JOIN `ON` predicate behavior and the v0.73 JSON relation classes. GeoPackage classes and typed GEOMETRY/SRID support remain present in the vendored class, while GeoPackage bridge binaries/fixtures continue to live only in the canonical NoSQLServer distribution rather than being duplicated into msqlshim.

## v0.10 binary prepared statements and cursors

The classic MySQL prepared-statement command family now has a real wire surface:

```text
COM_STMT_PREPARE
COM_STMT_EXECUTE
COM_STMT_SEND_LONG_DATA
COM_STMT_CLOSE
COM_STMT_RESET
COM_STMT_FETCH
```

`COM_STMT_PREPARE` allocates connection-local statement IDs, counts native
NoSQLServer parameter markers, and returns parameter metadata plus result-column
metadata for `SELECT * FROM <table>` and simple direct-column projections.
Prepared statements are connection-local and are discarded by
`COM_RESET_CONNECTION`.

`COM_STMT_EXECUTE` decodes the classic binary parameter vector and uses
NoSQLServer's `DatabaseParameterBinder` / database-core transaction machinery.
Prepared `SELECT` responses are returned as **binary protocol resultsets**, not
text rows. Prepared mutations return normal MySQL OK packets with affected-row
counts. The FIFO backend gate remains in force, so prepared execution has the
same reader/writer fairness as `COM_QUERY`.

Currently decoded bound parameter types are NULL, TINY, SHORT, LONG/INT24,
LONGLONG, VARCHAR/VAR_STRING/STRING, DECIMAL/NEWDECIMAL and BLOB-family values.
Date/datetime result values are emitted in MySQL binary value form. v0.13 also decodes common prepared-statement input values for FLOAT, DOUBLE, DATE, DATETIME/TIMESTAMP, TIME and YEAR. FLOAT/DOUBLE are converted through the backend DECIMAL value surface; TIME is preserved as canonical text because the current common DatabaseType vocabulary has no independent TIME type. NaN and Infinity are rejected rather than coerced into non-SQL numeric values. Query-attribute extensions are deliberately not claimed yet.

Read-only prepared cursors are supported when `COM_STMT_EXECUTE` carries
`CURSOR_TYPE_READ_ONLY` (`0x01`). Execution materializes the native result while
holding the normal fair backend ticket, releases the backend ticket, then exposes
the materialized rows through `COM_STMT_FETCH`. This preserves NoSQLServer's
single-engine concurrency boundary while allowing the client to fetch rows in
multiple protocol round trips without retaining the backend execution slot.

`COM_STMT_FETCH` honors the requested maximum row count, emits binary-protocol
rows, reports `SERVER_STATUS_CURSOR_EXISTS` while more rows remain, and reports
`SERVER_STATUS_LAST_ROW_SENT` when the cursor is exhausted. Reset, close,
re-execution, and connection reset discard any open cursor.

Independent regression:

```bash
python3 tests/mysql_wire_prepared_client.py 3456
```

It verifies prepare-time metadata, binary SELECT execution, read-only cursor
open/fetch/exhaustion semantics, statement reset, prepared INSERT affected rows,
close-with-no-response semantics, and continued use of the same TCP connection afterward.

## v0.21 package-reference execution

```bash
NOSQLSERVER_ROOT=/path/to/nosqlserver_v0.79 \
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8 \
OOREXX_CRYPTO_ROOT=/path/to/oorexx_crypto_v0.1 \
./run_tests.sh
```

Optional Unicode activation remains a NoSQLServer capability and may be enabled for the standalone listener by passing `TUTOR_ROOT` as its fourth argument.
