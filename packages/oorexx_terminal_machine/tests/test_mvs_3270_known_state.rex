call testKnownStates
say "PASS MVS 3270 KNOWN STATE"
exit 0

testKnownStates:
  call assertState "MVS.TSO.LOGON_PROMPT", .array~of("TK5 TSO", "Logon ===>")
  call assertState "HERCULES.TK5.WELCOME_PANEL", .array~of("Hercules Version  : 4.9.1.1-SDL-gee86c4d", "The MVS 3.8j", "Tur(n)key System")
  call assertState "MVS.TSO.PASSWORD_PROMPT", .array~of("ENTER CURRENT PASSWORD FOR HERC03-")
  call assertState "MVS.TSO.READY", .array~of("READY")
  call assertState "MVS.ISPF.PRIMARY_OPTION_MENU", .array~of("ISPF primary option menu", "Option ===>", "0  ISPF PARMS     Specify terminal and user parms", "6  COMMAND        Enter TSO command or CLIST", "Enter END command to terminate ISPF.")

  call assertNoState .array~of("Option ===>")
  call assertNoState .array~of("ISPF primary option menu")
  call assertNoState .array~of("ISPF primary option menu", "Option ===>")
  call assertNoState .array~of("IKJ000I NOT READY FOR COMMAND")
  call assertNoState .array~of("LISTCAT LEVEL(HERC03) READY")
  call assertNoState .array~of("READY TO PROCESS")
  call assertState "MVS.TSO.LOGON_PROMPT", .array~of("The MVS 3.8j", "Tur(n)key system", "Logon ===>", "RUNNING  TK5")
  return

assertState: procedure
  use arg wantedState, lines
  projected=makeSnapshot(lines)
  call assert projected~ok, "snapshot for " || wantedState
  cat=.MVS3270KnownStates~catalog
  m=cat~match(projected~value)
  call assert m~status=.TerminalMatchStatus~MATCH, "match status for " || wantedState || " got " || m~status
  call assert m~matchedStateId=wantedState, "wanted " || wantedState || " got " || m~matchedStateId
  return

assertNoState: procedure
  use arg lines
  projected=makeSnapshot(lines)
  call assert projected~ok, "negative snapshot"
  cat=.MVS3270KnownStates~catalog
  m=cat~match(projected~value)
  call assert m~status=.TerminalMatchStatus~NO_MATCH, "negative unexpectedly matched " || m~matchedStateId
  return

makeSnapshot: procedure
  use arg lines
  model=.PresentationSpace3270~new(24,80)
  stream=.DataStream3270~new(model)
  cp=stream~codepage
  rec=.Command3270~ERASE_WRITE || "02"x
  do i=1 to lines~items
    address=(i-1)*80
    rec ||= .Order3270~SBA || .Address3270~encode(address) || cp~encode(lines[i])
  end
  applied=stream~applyHostRecord(rec)
  if \applied~ok then return applied
  return .TN3270Snapshot~fromModel(model,cp)

assert: procedure
  use arg ok,msg
  if ok then return
  say "FAIL MVS 3270 KNOWN STATE:" msg
  exit 1

::requires "MVS3270KnownStates.cls"
::requires "TN3270Snapshot.cls"
