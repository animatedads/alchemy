runner = .MvsIntentionRunner~new("ED209ZZ", .MvsFixtureDiscoveryBackend~new(1))
call check runner, "what system am I on", "SYSTEM_IDENTITY", "ED209ZZ"
call check runner, "show jobs", "LIST_JOBS", "JOB00140"
call check runner, "show my datasets", "LIST_DATASETS", "FRED.COBOL"
call check runner, "what can I see", "DISCOVER_SCOPE", "jobs=4"
say "PASS read-only MVS intention surface"
exit 0
check: procedure
  use arg runner, utterance, expectedId, expectedText
  d = runner~input(utterance)
  if d~status \== "READY" then call fail utterance || " status=" || d~status
  if d~registration~id \== expectedId then call fail utterance || " intention=" || d~registration~id
  rendered = runner~render(d)
  if pos(expectedText, rendered) = 0 then call fail utterance || " missing '" || expectedText || "' in " || rendered
return
fail: procedure
  use arg message
  say "FAIL" message
  exit 1
::requires "MvsIntention.cls"
