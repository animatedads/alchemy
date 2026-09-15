conn=.DatabaseConnection~new("localhost",5432,"test","tester",.nil,"postgresql")
db=.Database~new(conn,.nil,.KeyExecutor~new); tx=db~transaction
tx~insertReturningKey("INSERT INTO people(name) VALUES ('Alice')","person_id"); rs=tx~commit
call assert (rs~status=.Error~SUCCESS),"commit"; call assert (rs~mutationResults[1]~generatedKey="123"),"key"
say "DATABASE TRANSACTION GENERATED KEY SMOKE: OK"; exit 0
assert: procedure; use arg condition,label; if \condition then exit 9; return
::class KeyExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  return .DatabaseCommandResult~new(0,"__oorexx_generated_key"||.endOfLine||"123"||.endOfLine||"INSERT 0 1"||.endOfLine,"",command,"PROCESS")
::requires "database_core.cls"
