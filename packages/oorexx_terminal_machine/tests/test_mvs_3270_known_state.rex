call testKnownState
say "PASS MVS 3270 KNOWN STATE"
exit 0

testKnownState:
  model=.PresentationSpace3270~new(24,80)
  stream=.DataStream3270~new(model)
  cp=stream~codepage
  rec=.Command3270~ERASE_WRITE || "02"x || .Order3270~SBA || .Address3270~encode(400) || .Order3270~SF || "20"x || cp~encode("TK5 TSO") || -
      .Order3270~SBA || .Address3270~encode(801) || cp~encode("Logon ===>")
  r=stream~applyHostRecord(rec)
  call assert r~ok, "record"
  projected=.TN3270Snapshot~fromModel(model,cp)
  call assert projected~ok, "snapshot"
  cat=.MVS3270KnownStates~catalog
  m=cat~match(projected~value)
  call assert m~status=.TerminalMatchStatus~MATCH, "match status"
  call assert m~matchedStateId="MVS.TSO.LOGON_PROMPT", "matched state"

  model2=.PresentationSpace3270~new(24,80)
  stream2=.DataStream3270~new(model2)
  r2=stream2~applyHostRecord(.Command3270~ERASE_WRITE || "02"x || cp~encode("READY"))
  call assert r2~ok, "unknown record"
  p2=.TN3270Snapshot~fromModel(model2,cp)
  m2=cat~match(p2~value)
  call assert m2~status=.TerminalMatchStatus~NO_MATCH, "do not guess READY state"
  return

assert: procedure
  use arg ok,msg
  if ok then return
  say "FAIL MVS 3270 KNOWN STATE:" msg
  exit 1

::requires "MVS3270KnownStates.cls"
::requires "TN3270Snapshot.cls"
