# NotNotes startup and high-performance SQL v0.1 (candidate)
Architecture: Tom Dyer. Integration finding/patch: CHATGPT. Existing Rexx/SQL backend: Claude (24 Oct 2026). No running estate host changed.

### Existing implementation to reuse
NotNotes owns application/intentions/form/report/PDF meaning. NoSQLServer/Database Core own DB provider semantics. Claude's packages/oorexx_rexxsql_backend_v0.1 already implements Mark Hessling Rexx/SQL 2.6B3 + Alchemy patches, using compiled SQLite SQL/indexes, and has a Gopher sphere. Do not build a substitute.

Native evidence under ooRexx r13196: tested against Library NotNotes dev17 ZIP SHA256 0b074b97081ea8c7759eab069f759e4c1a98bd471f537c5d1d3590b183a23312 (9 Oct edition; distinct from later Git revision until proven). O(N^2) sortByKey found and comparator patch passed native TPS designer regression. In cloned 954-document Alchemy corpus, app restore via FileDatabaseEngine ~27.1 s and comparator-patched CLI initialisation ~11.7 s; full semantic large-corpus window not qualified. Small corpus app 0.38 s/UI 0.003 s. These times do NOT prove a SQL speedup.

Backend's own Semantic Source Store evidence: indexed lookup ~80us for 20k rows versus file NoSQL full scan 1.2s/1000; GA import 17 files in ~3s versus 15/17 in 1547s. Those are not NotNotes timings. NoSQLServer v0.90/v0.91 SQLite writer still snapshots full DB each statement, not this fast SQL route.

### Missing before live NotNotes
MiniNotesPersistence~init hard-codes FileDatabaseEngine. Need explicitly selected/pinned RexxSqlSqliteSession persistence adapter with real schema mapping, valid bind/result semantics, WAL+transactions, indexed/limited collection queries, copied-corpus differential migration and reload, all field/relationship/approval/temporal evidence invariants, native tests and live acceptance. The Rexx/SQL driver is itself an ooRexx native library, not a Foreign Runtime call; Foreign Runtime and Crypto remain separate native/cryptographic prerequisites of the broader Alchemy runtime and must be pinned where consumed. Never route Crypto through each hot SQL lookup.

Patch here changes sort only; high-performance NotNotes DB migration NOT_IMPLEMENTED/NOT_RUN. Do not confuse a candidate with production acceptance. No secrets or runtime binaries included.