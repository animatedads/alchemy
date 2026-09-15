pgConn = .DatabaseConnection~new("localhost",5432,"test","tester",.nil,"postgresql")
pgDb=.Database~new(pgConn); pgTx=pgDb~transaction
pgTx~insertReturningKey("INSERT INTO people(name) VALUES ('Alice')","person_id")
pgCmd=pgDb~engine~compile(pgTx~prepare)
call assert (pgCmd~status=.Error~SUCCESS),"pg status"
call assert (pgCmd~stdinText~pos("RETURNING person_id AS __oorexx_generated_key;")>0),"pg returning"
myConn=.DatabaseConnection~new("localhost",3306,"test","tester",.nil,"mysql")
myDb=.Database~new(myConn); myTx=myDb~transaction
myTx~insertReturningKey("INSERT INTO people(name) VALUES ('Alice')","person_id")
myCmd=myDb~engine~compile(myTx~prepare)
call assert (myCmd~stdinText~pos("LAST_INSERT_ID()")>0),"mysql key"
say "DATABASE GENERATED KEY COMPILE SMOKE: OK"; exit 0
assert: procedure; use arg condition,label; if \condition then exit 9; return
::requires "database_core.cls"
