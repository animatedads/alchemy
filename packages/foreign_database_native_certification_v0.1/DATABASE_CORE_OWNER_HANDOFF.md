# Database Core owner handoff

Start from the exact current Database Core v0.46 lineage.

First native server-provider scope:
- PostgreSQL through Foreign Runtime -> libpq;
- MySQL/MariaDB through Foreign Runtime -> libmariadb/libmysqlclient;
- preserve the common Database Core API and result/error abstractions;
- keep one native connection handle throughout each transaction;
- use native parameter binding / prepared execution rather than SQL string interpolation;
- map structured native error/SQLSTATE information into existing Database Core error semantics;
- keep native handles process-local implementation details;
- retain specialist dump/restore command tooling separately if required.

Do not move MySQL client code into msqlshim.

After MySQL basic/prepared support is green, run the mandatory loopback:
Database Core -> Foreign Runtime -> libmariadb -> msqlshim -> NoSQLServer.

Return exact candidate ZIP, SHA-256, clean-extract evidence, inherited suite, PostgreSQL native tests, MySQL native tests, and loopback evidence.
