parser = .MySQLResultParser~new
out = "__oorexx_mutation" || .endOfLine || -
      "__OOREXX_MUTATION_COUNT__:1" || .endOfLine || -
      "__oorexx_mutation" || .endOfLine || -
      "__OOREXX_MUTATION_COUNT__:0" || .endOfLine || -
      "__oorexx_mutation" || .endOfLine || -
      "__OOREXX_MUTATION_COUNT__:7" || .endOfLine
cr = .DatabaseCommandResult~new(0, out, "", .nil, "PROCESS")
r = parser~parseMutationResults(cr)
call assert (r~items = 3), "three results"
call assert (r[1]~affectedRows = 1), "first"
call assert (r[2]~affectedRows = 0), "second"
call assert (r[3]~affectedRows = 7), "third"
say "DATABASE PREPARED BATCH MUTATION RESULT SMOKE: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::requires "database_core.cls"
