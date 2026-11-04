# NoSQLServer v0.80 — DB2 personality

v0.80 adds an explicit **DB2 personality module** above the generic NoSQLServer
SQL executor.  The design rule is simple: generic relational semantics stay in
`NoSQLServer.cls`; IBM Db2 product spelling, special registers and catalog shape
stay in `NoSQLServerDB2Personality.cls`.

This is a compatibility personality, **not a claim that NoSQLServer is IBM Db2**.

## Implemented surface

- `FETCH FIRST n ROW/ROWS ONLY`
- `OFFSET n ROW/ROWS FETCH NEXT n ROW/ROWS ONLY`
- `OPTIMIZE FOR n ROW/ROWS` accepted as an advisory clause
- trailing `FOR READ ONLY`
- special registers through `VALUES`: `CURRENT SERVER`, `CURRENT SCHEMA`,
  `CURRENT USER`, `SESSION_USER`, `SYSTEM_USER`, `USER`, `CURRENT DATE`,
  `CURRENT TIME`, `CURRENT TIMESTAMP`
- `SET CURRENT SCHEMA [=] name` and `SET SCHEMA name`
- `SYSIBM.SYSDUMMY1` with `IBMREQD='Y'`
- read-only synthetic `SYSCAT.TABLES`
- read-only synthetic `SYSCAT.COLUMNS`
- conservative DDL spelling aliases for representable types (`SMALLINT`,
  `BIGINT`, `INT`, `NUMERIC`, `DEC`, `TIMESTAMP`, `CLOB`)

The catalog views are generated from the authoritative NoSQLServer relation
metadata each time a personality executor is created.  They are not persisted
copies.

## Deliberately unsupported rather than faked

- `WITH UR` / uncommitted-read isolation semantics
- `GENERATED ... AS IDENTITY`
- full Db2 schema/authorization model
- packages, routines, sequences, triggers, tablespaces, buffer pools,
  partitioning, XML, temporal tables, MQTs and native Db2 administrative views
- Db2 data type range/precision identity where NoSQLServer has a broader or
  different internal representation

Unsupported semantics fail explicitly instead of being silently ignored.

## Usage

```rexx
engine = .FileDatabaseEngine~new(root)
db2 = .NoSQLServerDB2Personality~new(engine, "APPUSER", "APP")

r = db2~execute("SELECT id FROM customer ORDER BY id FETCH FIRST 10 ROWS ONLY")
r = db2~execute("SELECT TABNAME FROM SYSCAT.TABLES ORDER BY TABNAME")
r = db2~execute("VALUES CURRENT SERVER")
```

The personality object reports `personality="DB2"`; the underlying engine
continues to report `product="NoSQLServer"`.
