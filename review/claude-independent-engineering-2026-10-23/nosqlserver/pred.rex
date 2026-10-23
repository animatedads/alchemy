root = directory() || "/pred"; call SysMkDir root
sql = .NoSQLServerSQL~new(.FederatedDatabaseEngine~new(root))
call x "CREATE TABLE a (id VARCHAR PRIMARY KEY, k VARCHAR, r VARCHAR)"
call x "CREATE TABLE b (rid VARCHAR PRIMARY KEY, id VARCHAR, t VARCHAR, n INTEGER)"
call x "INSERT INTO a (id,k,r) VALUES ('a1','X','b1')"
call x "INSERT INTO a (id,k,r) VALUES ('a2','Y','b2')"
call x "INSERT INTO a (id,k,r) VALUES ('a3','Z','b3')"
call x "INSERT INTO b (rid,id,t,n) VALUES ('b1','a1','one',1)"
call x "INSERT INTO b (rid,id,t,n) VALUES ('b2','a2','two',2)"
call x "INSERT INTO b (rid,id,t,n) VALUES ('b3','a3','three',3)"
call q "SELECT id FROM a WHERE id IN ('a1','a2')"
call q "SELECT id FROM a WHERE id='a1' OR id='a2'"
call q "SELECT id FROM a WHERE (id='a1' OR id='a2') AND k='X'"
call q "SELECT r.rid,r.t FROM a o JOIN b r ON r.id=o.id AND r.rid=o.r WHERE o.id='a1' OR o.id='a3'"
call q "SELECT r.rid,r.t FROM a o JOIN b r ON r.id=o.id AND r.rid=o.r WHERE (o.id='a1' OR o.id='a3')"
call q "SELECT r.rid,r.t FROM a o JOIN b r ON r.id=o.id AND r.rid=o.r WHERE o.id IN ('a1','a3')"
call q "SELECT rid FROM b WHERE id='a1' OR id='a2' ORDER BY n DESC"
call q "SELECT rid,n FROM b WHERE (id='a1' OR id='a2' OR id='a3') AND (t='one' OR t='three') ORDER BY rid"
exit
x: parse arg s; rs = sql~execute(s); if rs~status \= "SUCCESS" then say "FAIL" s rs~message; return
q: parse arg s; rs = sql~execute(s)
  out = ""; if rs~status = "SUCCESS" then do r over rs~rows; do c over r~values~allIndexes~sort; out = out c"="r[c]; end; out = out ";"; end
  say left(rs~status,10) s; say "           " out rs~message; return
::requires "NoSQLServer.cls"
