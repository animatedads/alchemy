pg = .PostgreSQLResultParser~new
out = "INSERT 0 1" || .endOfLine || "UPDATE 3" || .endOfLine || "DELETE 2" || .endOfLine
cr = .DatabaseCommandResult~new(0, out, "", .nil, "PROCESS")
r = pg~parseMutationResults(cr)
call assert (r~items = 3), "pg result count"
call assert (r[1]~affectedRows = 1), "pg insert"
call assert (r[2]~affectedRows = 3), "pg update"
call assert (r[3]~affectedRows = 2), "pg delete"

my = .MySQLResultParser~new
out2 = "__oorexx_mutation" || .endOfLine || -
       "__OOREXX_MUTATION_COUNT__:4" || .endOfLine || -
       "__oorexx_mutation" || .endOfLine || -
       "__OOREXX_MUTATION_COUNT__:1" || .endOfLine
cr2 = .DatabaseCommandResult~new(0, out2, "", .nil, "PROCESS")
r2 = my~parseMutationResults(cr2)
call assert (r2~items = 2), "mysql result count"
call assert (r2[1]~affectedRows = 4), "mysql first"
call assert (r2[2]~affectedRows = 1), "mysql second"
say "DATABASE MUTATION RESULT SMOKE: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::requires "database_core.cls"
