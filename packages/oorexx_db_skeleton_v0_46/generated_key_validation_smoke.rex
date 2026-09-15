conn=.DatabaseConnection~new("localhost",5432,"test","tester",.nil,"postgresql"); db=.Database~new(conn)
tx1=db~transaction; tx1~insertReturningKey("UPDATE people SET name='x'","person_id"); v1=tx1~prepare~validate
call assert (v1~error=.Error~INVALIDOPERATION),"noninsert"
tx2=db~transaction; tx2~insertReturningKey("INSERT INTO people(name) VALUES ('x')","bad-column"); v2=tx2~prepare~validate
call assert (v2~error=.Error~INVALIDARGUMENT),"bad column"
say "DATABASE GENERATED KEY VALIDATION SMOKE: OK"; exit 0
assert: procedure; use arg condition,label; if \condition then exit 9; return
::requires "database_core.cls"
