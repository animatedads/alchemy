root = directory() || "/upd"; call SysMkDir root
sql = .NoSQLServerSQL~new(.FederatedDatabaseEngine~new(root))
call x "CREATE TABLE t (k VARCHAR PRIMARY KEY, v VARCHAR, n INTEGER)"
call x "INSERT INTO t (k,v,n) VALUES ('a','x',1)"
call x "UPDATE t SET v='plain' WHERE k='a'"
call x "UPDATE t SET v='with-dash' WHERE k='a'"
call x "UPDATE t SET v = 'with-dash' WHERE k='a'"
call x "UPDATE t SET v='a b|c' WHERE k='a'"
call x "UPDATE t SET v='it''s' WHERE k='a'"
call x "UPDATE t SET v='x', n=2 WHERE k='a'"
call x "UPDATE t SET n=3 WHERE k='a'"
call x "UPDATE t SET v='ssr-f96058f2f6b6e1420dcff84e447004cf' WHERE k='a'"
call x "UPDATE t SET v='12-34' WHERE k='a'"
rs = sql~execute("SELECT v,n FROM t WHERE k='a'"); say "final v=" rs~rows[1]["v"] "n=" rs~rows[1]["n"]
exit
x: parse arg s; rs = sql~execute(s); say left(rs~status,12) s; if rs~status \= "SUCCESS" then say "             " rs~message; return
::requires "NoSQLServer.cls"
