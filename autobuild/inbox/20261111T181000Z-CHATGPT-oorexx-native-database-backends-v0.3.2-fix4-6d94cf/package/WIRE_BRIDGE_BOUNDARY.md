# MySQL client/backend versus MySQL Wire Bridge boundary

Canonical inbound package name: `mysql_wire_bridge`.
Historical name: `msqlshim` (deprecated compatibility identity).

`MySQLNativeBackend` is an outbound Database Core implementation. It uses the MariaDB/MySQL client ABI through Foreign Runtime and its narrow native bulk adapter. It does not call, embed, require, or route through MySQL Wire Bridge.

MySQL Wire Bridge is an inbound server-side compatibility endpoint. It accepts MySQL classic wire clients and presents NoSQLServer through that protocol. It is not Database Core's native MySQL client.

Direction is therefore part of component identity and capability publication. A selector must never treat these two components as interchangeable simply because both speak MySQL semantics at one boundary.
