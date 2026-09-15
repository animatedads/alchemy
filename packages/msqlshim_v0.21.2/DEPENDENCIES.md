# msqlshim v0.21.2 dependency boundary

`msqlshim` owns the MySQL/MariaDB classic wire/session compatibility layer. It does not own NoSQLServer source.

Validated package-reference baseline inherited from the v0.20 reconciliation branch:

| Environment | Package | Required path |
| --- | --- | --- |
| `NOSQLSERVER_ROOT` | `nosqlserver_v0.79` | `src/NoSQLServer.cls` |
| `ALCHEMY_OBJECTS_ROOT` | `alchemy_objects_v0.8` | `src/AlchemyObject.cls` |
| `OOREXX_CRYPTO_ROOT` | `oorexx_crypto_v0.1` | `src/crypto.cls` |

`run_tests.sh` constructs `REXX_PATH` from these roots. msqlshim contains no `NoSQLServer.cls` and no `vendor/` directory; `tests/dependency_boundary_smoke.sh` fails if that boundary regresses.

TUTOR remains optional and external. The standalone listener accepts an optional fourth `TUTOR_ROOT` argument but does not require or redistribute TUTOR.

NoSQLServer owns SQL, storage, GeoPackage/native SQLite, JSON, spatial and Unicode semantics. msqlshim owns only MySQL/MariaDB classic-protocol/session compatibility.
