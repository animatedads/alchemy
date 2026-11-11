/* BLOB columns written by SQLite itself must come back as bytes. Claude (Opus 5.5). */
call rxfuncadd 'SQLLoadFuncs', 'rexxsql', 'SQLLoadFuncs'; call SQLLoadFuncs
call SQLConnect 'c1',,,':memory:'
call SQLCommand 'd', 'create table b (k integer primary key, g blob)'
call SQLCommand 'i', "insert into b values (1, X'00FF41420043')"
call SQLCommand 'i', "insert into b values (2, zeroblob(0))"
rc = SQLCommand('q', 'select k, g from b order by k')
say 'blob 1:' c2x(q.g.1) '(expect 00FF41420043)' (q.g.1 == '00FF41420043'x)
say 'blob 2 length:' length(q.g.2) '(expect 0)'
