pg=.PostgreSQLResultParser~new
cr=.DatabaseCommandResult~new(0,"__oorexx_generated_key"||.endOfLine||"42"||.endOfLine||"INSERT 0 1"||.endOfLine,"",.nil,"PROCESS")
r=pg~parseMutationResults(cr)
call assert (r~items=1),"pg count"; call assert (r[1]~generatedKey="42"),"pg key"
my=.MySQLResultParser~new
cr2=.DatabaseCommandResult~new(0,"__OOREXX_MUTATION_RESULT__:1:77"||.endOfLine,"",.nil,"PROCESS")
r2=my~parseMutationResults(cr2)
call assert (r2~items=1),"my count"; call assert (r2[1]~generatedKey="77"),"my key"
say "DATABASE GENERATED KEY PARSE SMOKE: OK"; exit 0
assert: procedure; use arg condition,label; if \condition then exit 9; return
::requires "database_core.cls"
