/* Clean-checkout consumer smoke.
 * Builds only the minimum TPS schema needed by the Help Desk, using committed
 * package sources rather than the historical delivery ZIP/data fixture.
 */
root = value("TEST_DATA_ROOT",,"ENVIRONMENT")
if root = "" then do
  say "FAIL TEST_DATA_ROOT required"
  exit 2
end

app = .MiniNotesApp~new(root)
if app~userFormatCanonicalName("TPS Report") = "" then do
  fields = .Array~new
  fields~append(fieldSpec("TPSNumber","TPS Number","IDENTIFIER"))
  fields~append(fieldSpec("User","User","USER_REFERENCE"))
  fields~append(fieldSpec("Cost","Cost","MONEY"))
  ignore = app~installUserFormat("TPS Report", fields)
end
if app~userFormatCanonicalName("TPS Report Review") = "" then do
  fields = .Array~new
  ref = fieldSpec("TheTPSReport","The TPS Report","DOCUMENT_REFERENCE")
  ref["REF_TARGET"] = "TPS Report"
  fields~append(ref)
  fields~append(fieldSpec("TheReview","The Review","TEXT"))
  fields~append(fieldSpec("TheRating","The Rating","TEXT"))
  ignore = app~installUserFormat("TPS Report Review", fields)
end
ignore = app~persistNow

session = .InitechHelpDeskSession~new(root,"alice")
discovery = session~discover
call assertEq "MININOTES.SEMANTIC_APPLICATION/1", discovery["CONTRACT"], "semantic application discovery"
call assertTrue discovery["SPECIALISTS"]~items >= 1, "specialist discovered"

logged = session~handle("log business clean checkout smoke")
call assertEq "SUCCESS", logged["STATUS"], "business log through committed source closure"

health = session~handle("show NotNotes health and metrics")
call assertEq "SUCCESS", health["STATUS"], "read-only instrumentation specialist"
call assertEq "INSTRUMENTATION", health["AUTHORITY"], "instrumentation stays evidence authority"

closed = session~close
call assertEq "SUCCESS", closed["RATING"], "session TPS process succeeds"
call assertTrue closed["TPS_KEY"] <> "", "session TPS report created"
call assertTrue closed["REVIEW_KEY"] <> "", "linked TPS review created"

next = .InitechHelpDeskSession~new(root,"alice")
history = next~handle("what happened in " || closed["TPS_NUMBER"])
call assertEq "SUCCESS", history["STATUS"], "later session reads prior TPS process evidence"
call assertContains history["TEXT"], closed["REVIEW_KEY"], "linked review is authoritative evidence"

say "PASS clean-checkout Initech Help Desk source closure"
exit 0

::routine fieldSpec
  use strict arg name,label,type
  d=.Directory~new
  d["NAME"]=name
  d["LABEL"]=label
  d["TYPE"]=type
  return d

::routine assertEq
  use strict arg expected,actual,label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end

::routine assertTrue
  use strict arg condition,label
  if \condition then do
    say "FAIL" label
    exit 1
  end

::routine assertContains
  use strict arg text,needle,label
  if pos(needle,text)=0 then do
    say "FAIL" label "missing="needle
    exit 1
  end

::requires "InitechHelpDesk.cls"
