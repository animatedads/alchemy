parse source . . here
root=filespec("L",here)||"/.."
dataRoot=value("TEST_DATA_ROOT",,"ENVIRONMENT")
if dataRoot="" then do; say "FAIL TEST_DATA_ROOT required"; exit 2; end

session=.InitechHelpDeskSession~new(dataRoot,"alice")

d=session~discover
call assertTrue d["REPORTS"]~items >= 6,"management dataset saved reports discovered"
call assertTrue d["FORMATS"]~items >= 10,"management dataset formats discovered"

r=session~handle("show the Management Review Selection Report")
call assertEq "SUCCESS",r["STATUS"],"management selection report"
call assertEq "Management Review Selection Report",r["REPORT_NAME"],"selection report identity"
call assertEq 12,r["COUNT"],"selection report contains all twelve TPS links"
call assertContains r["TEXT"],"MRS-0001","selection report resolves management selection"

r=session~handle("show the Report by the Management Consultants")
call assertEq "SUCCESS",r["STATUS"],"management consultant report"
call assertEq "Report by the Management Consultants",r["REPORT_NAME"],"consultant report identity"
call assertEq 1,r["COUNT"],"one management consultant report"
call assertContains r["TEXT"],"MRS-0001","consultant report linked selection"
call assertContains r["TEXT"],"TAMC-0001","consultant report linked time and motion consultant"
call assertContains r["TEXT"],"SC-0001","consultant report linked synergy consultant"

/* No help-desk hard-coded TPS-to-finding map: the live DOCUMENT_REFERENCE
 * metadata identifies the supporting finding format and relation. */
r=session~handle("what did the consultants find about TPS-2026-102 and what did they recommend?")
call assertEq "SUCCESS",r["STATUS"],"linked finding traversal"
call assertEq "LINKED_TPS_EVIDENCE",r["INTENTION"],"linked evidence intention"
call assertEq 1,r["COUNT"],"one finding linked to TPS-2026-102"
call assertContains r["TEXT"],"MCF-0002","finding document resolved"
call assertContains r["TEXT"],"800.00 belongs to alice","finding content resolved"
call assertContains r["TEXT"],"Record process category","recommended action resolved"

before=session~app~tpsDocuments~items
close=session~close
call assertEq "SUCCESS",close["RATING"],"management help-desk session succeeds"
call assertEq before+1,session~app~tpsDocuments~items,"session writes mandatory TPS report"
review=session~app~byKey(close["REVIEW_KEY"])
call assertEq close["TPS_KEY"],review~field("TheTPSReport")~string,"session review links report"
call assertEq "SUCCESS",review~field("TheRating")~string,"session review rates process success"

say "PASS Initech management-review Help Desk over live NotNotes relationships"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected \== actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed:" label); end
::routine assertTrue
  use strict arg condition,label
  if \condition then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed:" label); end
::routine assertContains
  use strict arg text,needle,label
  if pos(needle,text)=0 then do; say "FAIL" label "missing="needle; raise syntax 88.900 array("test assertion failed:" label); end
::requires "InitechHelpDesk.cls"
