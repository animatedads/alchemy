pg = .PostgreSQLResultParser~new
out = "__oorexx_frame" || .endOfLine || -
      "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
      "id" || "09"x || "name" || .endOfLine || -
      "1" || "09"x || "Alice" || .endOfLine || -
      "__oorexx_frame" || .endOfLine || -
      "__OOREXX_RESULT_END_1__" || .endOfLine || -
      "__oorexx_frame" || .endOfLine || -
      "__OOREXX_RESULT_BEGIN_2__" || .endOfLine || -
      "value" || .endOfLine || -
      "42" || .endOfLine || -
      "__oorexx_frame" || .endOfLine || -
      "__OOREXX_RESULT_END_2__" || .endOfLine
cr = .DatabaseCommandResult~new(0, out, "", .nil, "PROCESS")
frames = pg~parseQueryFrames(cr)
call assert frames~items = 2, "two frames"
call assert frames[1]~rowCount = 1, "first row count"
call assert frames[1]~rows[1]~rawAt("name") = "Alice", "first value"
call assert frames[2]~rows[1]~rawAt("value") = "42", "second value"
say "DATABASE QUERY FRAME SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
