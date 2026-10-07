manager = .DFDevelopmentManager~new
specialist = .DFSpecialistProfile~new("ALOG-1", "ALCHEMY_LOG", "ooRexx")
manager~registerSpecialist(specialist)
a = .DFAssignment~new("A1", "FRAMEWORK", "ALCHEMY_LOG", "ooRexx", "document append")
manager~addAssignment(a)
bug = manager~raiseBug(a, "GWEN", "append reports success after store failure", "observed while documenting append", "source graph line 88")
call assertEqual "RAISED", bug~status, "raised status"
call assertEqual 1, manager~allocationQueue~waiting~items, "bug fed back to allocation"
call assertEqual bug~id, manager~allocationQueue~waiting[1]~sourceId, "allocation source bug"
call assertEqual 0, bug~repairPermitted("GWEN"), "reporter expressly cannot repair"
manager~allocateBug(bug~id, "Error condition", "ALOG-1")
call assertEqual "ERROR_CONDITION", bug~bugClass, "classification"
call assertEqual 0, bug~repairPermitted("GWEN"), "reporter still cannot repair"
call assertEqual 1, bug~repairPermitted("ALOG-1"), "assigned worker may repair"
call assertEqual 0, manager~allocationQueue~waiting~items, "allocated bug no longer waiting"
say "PASS test_bug_lane"
exit 0
assertEqual: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return
::requires "DevelopmentFloor.cls"
