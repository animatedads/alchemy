call assert .Error~SUCCESS = "SUCCESS", "success constant"
call assert .Error~NOTEXECUTED = "NOTEXECUTED", "not executed constant"
call assert .Error~ROLLEDBACK = "ROLLEDBACK", "rolled back constant"
call assert .Error~COMMANDFAILED = "COMMANDFAILED", "command failed constant"

ok = .DatabaseCommandResult~new(0)
call assert ok~status = .Error~SUCCESS, "command success status"
call assert ok~error = .Error~SUCCESS, "command success error"

bad = .DatabaseCommandResult~new(7)
call assert bad~status = .Error~FAILED, "command failure status"
call assert bad~error = .Error~COMMANDFAILED, "command failure error"

rs = .DatabaseTransactionResult~new(.Error~NOTEXECUTED, .Error~INVALIDSTATE)
call assert rs~status = .Error~NOTEXECUTED, "requested status comparison"
call assert rs~error = .Error~INVALIDSTATE, "error comparison"

say "DATABASE ERROR CONSTANT SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
