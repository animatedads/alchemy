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
if operation="EXECUTIONOFF" then do
  target~setExecutionEvidencePolicy(0)
  return "execution evidence disabled"
end
if operation="INSTRUMENT" then do
  target~instrumentMethod("WORK")
  return "instrumented"
end
if operation="UNINSTRUMENT" then do
  target~uninstrumentMethod("WORK")
  return "uninstrumented"
end
raise syntax 88.900 array("unknown mutation operation " || operation)
