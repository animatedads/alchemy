## v0.21.2

- Repair split public package identity in v0.21.1: Alchemy metadata, compatibility snapshot, `@@msqlshim_version`, wire identity regression, and package validation now agree on `0.21.2`.
- Preserve the v0.21.1 native zlib/DEFLATE precision repair (`::options digits 30`) unchanged.
- Add a deterministic 100,000-byte Adler-32 / native zlib round-trip regression (`E20C346E`) so the v0.21.1 precision fix is directly covered.
- No SQL, storage, authentication, transport framing, NoSQLServer, or dependency-boundary change.

## v0.21.1

- Repair native zlib/DEFLATE arithmetic precision by placing `::options digits 30` at the top of `src/MySQLDeflate.cls`.
- Fixes the shared-Deflate Adler-32 mismatch caused by default ooRexx numeric precision on the checksum/arithmetic path.
- No protocol, NoSQLServer, or dependency-boundary change; NoSQLServer remains external package-reference only.

## v0.21

- Reconcile both independently-developed v0.20 lines without discarding either.
- Keep the NoSQLServer v0.79 / Alchemy Objects v0.8 structural baseline, preferred `INIT:SUPER` construction, sealer/capability-authority propagation, optional external `TUTOR_ROOT`, and strict no-vendor/no-embedded-NoSQLServer boundary.
- Add `MySQLSessionRegistry`, deterministic connection ids, `SHOW PROCESSLIST`, `SHOW FULL PROCESSLIST`, and classic `COM_PROCESS_INFO` (`0x0a`).
- Derive `Threads_connected` and cumulative `Connections` from the active-session registry.
- Keep process-list `Info` intentionally blank: SQL text, parameters, rows, and authentication bytes are not retained merely for observability.
- Propagate the host Alchemy sealer/capability authority into the session registry as well as the backend scheduler and connections.
- Add the process-list raw-wire regression to the package suite.

## v0.20

- Rebase service-object infrastructure from Alchemy Objects v0.5 to v0.8.
- Move `MySQLWireServer`, `MySQLBackendGate`, and `MySQLWireConnection` to the
  preferred `INIT:SUPER` construction chain and verify all three at STANDARD.
- Propagate host-supplied sealer/capability authority from the server into the
  backend scheduler and connection service objects.
- Rebind the package-reference backend from NoSQLServer v0.77 to v0.79.
- Keep the v0.19 handshake-attribute/database-selection protocol surface and all
  earlier query-attribute/prepared/compression/fairness behaviour unchanged.
- Restore optional standalone `TUTOR_ROOT` launcher support without making
  TUTOR a dependency.
- Keep the no-vendor/no-embedded-NoSQLServer boundary.

## v0.19

- add and advertise `CLIENT_CONNECT_ATTRS`
- parse the MySQL 4.1 handshake response rather than treating everything after capability flags as opaque
- retain connection-local user, client max packet, character set, auth plugin name, requested database, and length-encoded connection attributes
- honor `CLIENT_CONNECT_WITH_DB` so the initial handshake database becomes the session database before the first command
- reject malformed/truncated connection-attribute blocks during handshake
- keep connection attribute values out of Alchemy telemetry
- keep NoSQLServer strictly package-referenced; no `NoSQLServer.cls`, backend copy, or `vendor/` tree is present
- add `mysql_wire_connect_attrs_client.py` regression and retain the complete v0.18 wire/concurrency/prepared suite

# v0.16

- Adopt Alchemy Objects v0.4.3 for `MySQLWireServer`, `MySQLBackendGate`, and `MySQLWireConnection` through a common `MySQLShimAlchemyObject` service base.
- Add bounded `compatibilitySnapshot()` evidence distinguishing implemented protocol features from deliberately absent TLS/authentication/zstd.
- Add object identities, method contracts, lifecycle/use telemetry, requirements, and detached relationships without logging SQL text, parameter values, authentication bytes, or row contents.
- Permit an optional host-provided Alchemy sealer/authority on the server constructor; existing three-argument construction remains unchanged.
- Carry an exact deterministic Alchemy v0.4.3 + oorexx_crypto v0.1 runtime closure for normal project-root execution.
- Refresh vendored NoSQLServer from canonical v0.74 to canonical v0.75, without moving SQL semantics into the shim.
- Add focused Alchemy/base and v0.75 backend snapshot regressions plus a package runner.

# msqlshim v0.15

- Advertise and decode `CLIENT_QUERY_ATTRIBUTES` (bit 27).
- Decode the extended `COM_QUERY` parameter/attribute prefix and bind positional
  values through NoSQLServer's native `DatabaseParameterBinder`.
- Decode `PARAMETER_COUNT_AVAILABLE` in `COM_STMT_EXECUTE`, preserving the first
  prepared-placeholder values while accepting additional named query attributes.
- Added an independent raw-socket query-attributes regression.
- Kept legacy packet layouts unchanged for clients that do not negotiate the
  capability.

# msqlshim changelog

## v0.17

- exposed bounded component/backend/base identity through MySQL system variables and `SHOW VARIABLES`
- added an independent wire identity regression
- replaced fixed prepared-test fixture IDs with run-unique IDs so historical demo rows cannot create false duplicate failures
- restored the full prepared statement/cursor/typed-value regression to the package suite
- retained canonical NoSQLServer v0.75 and Alchemy Objects v0.4.3


## v0.06

Protocol-surface expansion from the accepted v0.05 checkpoint.

- rebound vendored backend to untouched NoSQLServer v0.58
- added native `CLIENT_COMPRESS` / zlib compressed-protocol support
  - compression is negotiated only when the client requests `CLIENT_COMPRESS`
  - connection-phase handshake remains uncompressed, compression starts after OK
  - incoming zlib streams support stored, fixed-Huffman and dynamic-Huffman DEFLATE
  - outgoing frames use native fixed-Huffman zlib when it is smaller and otherwise use the protocol-defined uncompressed payload form
- added proper MySQL payload fragmentation at the 0xFFFFFF packet boundary
- added utility-command coverage:
  - `COM_FIELD_LIST`
  - `COM_STATISTICS`
  - `COM_DEBUG`
  - `COM_SET_OPTION` for multi-statement enable/disable session state
  - `COM_RESET_CONNECTION`
- added compression/session status personality:
  - `protocol_compression_algorithms = zlib,uncompressed`
  - `Compression`
  - `Compression_algorithm`
  - `Compression_level`
- retained v0.05 multi-client unguarded socket behavior
- retained project-root `::requires` convention

Not claimed in v0.06:

- TLS / `CLIENT_SSL`
- real account authentication
- binary prepared statement protocol (`COM_STMT_*`)
- zstd compression
- replication/binlog commands
- local infile upload

## v0.07

Concurrency isolation repair discovered by live mixed compressed/uncompressed use.

- all request-path methods on `MySQLWireServer` are now explicitly `unguarded`
- per-client mutable protocol state remains on `MySQLWireConnection`
- a long SQL execution or blocked result-stream send on one client can no longer hold the server object guard and serialize:
  - another client's handshake greeting
  - another client's `COM_QUERY`
  - another client's result encoding
- compressed and uncompressed connections can coexist concurrently; compression remains a connection-time capability and is not switched mid-connection
- added `tests/mysql_wire_mixed_concurrency.py`
  - client A negotiates `CLIENT_COMPRESS`
  - client A requests a deliberately large result and does not read it, forcing server-side send backpressure
  - client B connects without compression and executes `SELECT @@version` while A remains blocked
  - v0.06 reproduces the defect: client B times out before receiving its greeting
  - v0.07 passes: client B completes the query while A remains blocked
- vendored backend remains byte-for-byte NoSQLServer v0.58

## v0.08

Backend scheduling fairness repair discovered by sustained PyMySQL writes plus concurrent MariaDB reads.

- added `MySQLBackendGate`, a FIFO ticket gate in front of native backend SQL execution
- all ordinary `SELECT` / `WITH` queries and mutations acquire a backend ticket before entering the single shared `FileDatabaseEngine`
- the ticket is released immediately after the backend result is materialized, before MySQL packet encoding/socket writes
- prevents a fast sequential writer from repeatedly reacquiring the ooRexx engine guard ahead of an already queued reader
- preserves the existing single-engine isolation boundary; v0.08 does **not** create an independent `FileDatabaseEngine` per socket
- added `tests/mysql_wire_backend_fairness.py`, which keeps a writer active while a second client queues `COUNT(*)` and verifies the reader completes before the writer drains its workload
- retained v0.07 mixed compressed/uncompressed transport-concurrency fix
- vendored backend remains byte-for-byte NoSQLServer v0.58


## v0.09

Binary prepared-statement protocol expansion from the accepted v0.08 fairness
checkpoint.

- added connection-local prepared statement registry and statement IDs
- added `COM_STMT_PREPARE`
  - parameter-marker counting uses NoSQLServer's native `DatabaseParameterBinder`
  - returns parameter metadata
  - returns prepare-time column metadata for `SELECT *` and simple direct-column projections
- added `COM_STMT_EXECUTE`
  - classic NULL bitmap and parameter type vector decoding
  - retains parameter types when `new_params_bind_flag=0`
  - integer, string, decimal, NULL and BLOB-family bound values
  - native NoSQLServer binder/database-core execution
  - SELECT responses use MySQL binary-protocol result rows
  - mutations return affected-row OK packets
- added `COM_STMT_SEND_LONG_DATA`, `COM_STMT_RESET`, and no-response `COM_STMT_CLOSE`
- `COM_STMT_FETCH` is recognized and explicitly rejected until cursor semantics are implemented
- prepared execution uses the same v0.08 FIFO backend gate; no second engine instance is introduced
- added `tests/mysql_wire_prepared_client.py`
- retained all v0.08 text, compression, utility, mixed-concurrency and fairness regressions
- vendored backend remains byte-for-byte NoSQLServer v0.58

Not yet claimed:

- prepared-statement cursors / `COM_STMT_FETCH`
- FLOAT/DOUBLE/TIME bound parameter decoding
- optional resultset metadata / query attributes
- TLS / `CLIENT_SSL`
- real account authentication
- zstd compression
- replication/binlog commands
- local infile upload


## v0.10

Prepared-statement cursor completion from the v0.09 binary-protocol checkpoint.

- added read-only server-side prepared cursors for `CURSOR_TYPE_READ_ONLY`
- `COM_STMT_EXECUTE` now accepts cursor flag `0x01` for result-producing statements
  - executes/materializes through the same NoSQLServer/database-core path and FIFO backend gate
  - returns prepared-result metadata without row packets
  - sets `SERVER_STATUS_CURSOR_EXISTS` in the metadata terminator
- added `COM_STMT_FETCH`
  - fetches at most the requested row count
  - returns binary-protocol rows
  - keeps `SERVER_STATUS_CURSOR_EXISTS` while rows remain
  - returns `SERVER_STATUS_LAST_ROW_SENT` on the final fetch and closes the cursor
- re-executing, resetting, closing, or resetting the connection clears cursor state
- unsupported FOR UPDATE / scrollable cursor flags are rejected explicitly rather than silently downgraded
- refactored prepared binary result encoding so ordinary execution and cursor fetch share the same row encoder
- extended `tests/mysql_wire_prepared_client.py` with a 2-row + 3-row cursor-fetch regression and exhausted-cursor check
- retained v0.08 FIFO fairness and v0.07 mixed compression concurrency behaviour
- vendored backend remains byte-for-byte NoSQLServer v0.58

Not yet claimed:

- FLOAT/DOUBLE/TIME bound parameter decoding
- optional resultset metadata / query attributes
- TLS / `CLIENT_SSL`
- real account authentication
- zstd compression
- replication/binlog commands
- local infile upload
## v0.11

Backend snapshot refresh only; MySQL protocol behavior remains the v0.10 surface.

- bumped the shim package to v0.11
- replaced `vendor/NoSQLServer.cls` byte-for-byte with canonical NoSQLServer v0.73
- no MySQL-specific changes were made to the vendored backend
- retained all v0.10 prepared cursor, v0.09 prepared statement, v0.08 FIFO fairness, and v0.07 mixed-compression behavior
- verified canonical NoSQLServer v0.73 still contains and passes its GeoPackage provider, typed geometry/SRID, federation, and DB Core metadata regressions
- GeoPackage bridge source/binary and fixtures remain owned by the canonical NoSQLServer package and are not duplicated into msqlshim

## v0.12

Backend snapshot refresh only; MySQL protocol behavior remains the v0.10 surface.

- bumped the shim package to v0.12
- replaced `vendor/NoSQLServer.cls` byte-for-byte with canonical NoSQLServer v0.74
- retained all v0.10 prepared cursor, v0.09 prepared statement, v0.08 FIFO fairness, and v0.07 mixed-compression behavior
- added a backend guard for NoSQLServer release/SQL level 0.74
- guard now also asserts `SQLiteDatabaseEngine` and `SQLiteNativeDatabase` are present
- verified canonical NoSQLServer v0.74 retains GeoPackage typed geometry/SRID and JSON provider classes while replacing the old C GeoPackage bridge with native ooRexx SQLite binary reading
- no MySQL-specific changes were made to the vendored backend


## v0.13

Prepared binary-value coverage expansion; backend remains canonical NoSQLServer v0.74.

- added `MYSQL_TYPE_FLOAT` and `MYSQL_TYPE_DOUBLE` input decoding from IEEE-754 little-endian wire values
- finite FLOAT/DOUBLE values are bound through NoSQLServer `DatabaseValue~decimal`; NaN/Infinity are rejected explicitly
- added binary `DATE`, `DATETIME`, `TIMESTAMP`, `TIME`, and `YEAR` parameter decoding
- DATE and DATETIME/TIMESTAMP bind through native common database value constructors
- TIME is preserved as canonical text because the current common database type vocabulary has no distinct TIME type
- retained read-only prepared cursor / `COM_STMT_FETCH` behavior and the v0.08 FIFO backend gate
- extended the independent prepared client regression with FLOAT/DOUBLE round trips and DATE/DATETIME/TIME canonicalization checks
- vendored backend remains byte-for-byte canonical NoSQLServer v0.74; no NoSQLServer source changes

Still not claimed: query attributes / optional metadata, TLS, real account authentication, zstd compression, replication/binlog commands, local infile upload.


## v0.14

Modern result-set framing expansion from the v0.13 typed prepared-parameter checkpoint.

- retained the byte-identical canonical NoSQLServer v0.74 backend snapshot
- added `CLIENT_DEPRECATE_EOF` capability advertisement and handling
  - legacy clients retain EOF packets
  - clients requesting EOF deprecation omit the metadata EOF separator
  - final text/binary result terminators use the OK-style `0xFE` packet
  - prepared parameter/column metadata separators also honor EOF deprecation
- added `CLIENT_OPTIONAL_RESULTSET_METADATA` capability advertisement
  - result-set headers include `metadata_follows` when negotiated
  - v0.14 always reports `RESULTSET_METADATA_FULL` and continues sending complete column definitions
- added `tests/mysql_wire_modern_metadata_client.py` to independently negotiate both capabilities and verify packet framing
- retained all legacy text, compression, utility, prepared/cursor, mixed-concurrency and FIFO-fairness behavior

Still not claimed:

- `CLIENT_QUERY_ATTRIBUTES` / COM_QUERY named attributes
- zstd compression
- TLS / real account authentication
- replication/binlog commands
- LOCAL INFILE
