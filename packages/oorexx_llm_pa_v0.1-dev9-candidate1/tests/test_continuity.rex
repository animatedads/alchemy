parse source . . here
root = filespec("L", here)
path = root || "/continuity.brief"
address command "rm -f" path
brief = .LlmPaContinuityBrief~new(path)
missing = brief~read
call mustFail missing, "missing brief"
published = brief~publish("OBJECTIVE: finish PA workflow integration; NEXT: add broker executor; UNKNOWN: live fleet status", "gemma:gemma2:2b")
call must published, "publish brief"
loaded = brief~read
call must loaded, "read prepared brief"
call mustBool loaded~value["delivery"] = "PREPARED_LOCAL_READ", "prepared delivery"
call mustBool loaded~value["source"] = "gemma:gemma2:2b", "brief provenance"
call mustBool loaded~value["text"]~pos("OBJECTIVE:") > 0, "brief body"
address command "rm -f" path
say "PASS test_continuity"
exit 0

must: procedure
  use arg answer, label
  if \answer~ok then do; say "FAIL" label answer~code answer~detail; exit 1; end
return
mustFail: procedure
  use arg answer, label
  if answer~ok then do; say "FAIL" label "unexpected OK"; exit 1; end
return
mustBool: procedure
  use arg ok, label
  if \ok then do; say "FAIL" label; exit 1; end
return

::requires "LlmPaContinuity.cls"
