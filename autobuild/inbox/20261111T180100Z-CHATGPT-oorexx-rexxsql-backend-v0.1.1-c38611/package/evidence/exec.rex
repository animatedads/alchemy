/* SQLPREPARE + SQLEXECUTE of row-returning non-SELECT statements must run them. */
call rxfuncadd 'SQLLoadFuncs', 'rexxsql', 'SQLLoadFuncs'; call SQLLoadFuncs
db = directory() || '/exec.sqlite'; call SysFileDelete db
call SQLConnect 'c1',,,db
call SQLCommand 'd', 'create table t (k varchar primary key)'
call SQLPrepare 'p1', "insert into t (k) values ('a') returning k"
rc = SQLExecute('p1'); say 'execute RETURNING rc=' rc sqlca.sqlerrm
call SQLPrepare 'p2', 'pragma journal_mode=wal'
rc = SQLExecute('p2'); say 'execute PRAGMA rc=' rc sqlca.sqlerrm
call SQLCommand 'q', 'select count(*) as n from t'; say 'rows in t:' q.~at('N.1') '(expect 1)'
call SQLCommand 'q', 'pragma journal_mode'; say 'journal mode:' q.~at('JOURNAL_MODE.1') '(expect wal)'
call SQLPrepare 'p3', 'select k from t'
rc = SQLExecute('p3'); say 'execute SELECT rc=' rc '(unchanged behaviour: not executed, rc 0)'
