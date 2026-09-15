use strict arg target, operation
operation=operation~string~translate
if operation="WAIVE" then do
  target~recordRequirementResult("ENV:HOST-READY","WAIVED","customer self-waiver")
  return "waived"
end
if operation="DISABLE" then do
  target~setInstrumentationRule("DEMO.REPEAT",.false,"ALL")
  return "disabled"
end
raise syntax 88.900 array("unknown mutation operation " || operation)
