parse source . . here
root=filespec("L",here)||"/.."
dataRoot=value("TEST_DATA_ROOT",,"ENVIRONMENT")
if dataRoot="" then do; say "FAIL TEST_DATA_ROOT required"; exit 2; end
session=.InitechHelpDeskSession~new(dataRoot,"alice")

d=session~discover
call assertTrue d["REPORTS"]~items >= 3,"live report discovery"
call assertTrue d["FORMATS"]~items >= 4,"live format discovery includes business log"
call assertEq "MININOTES.SEMANTIC_APPLICATION/1",d["CONTRACT"],"discovery uses NotNotes semantic application contract"
call assertTrue d["SURFACES"]~items > 0,"semantic surfaces discovered"
call assertTrue d["SPECIALISTS"]~items >= 1,"live specialist discovery"
call assertEq "instrumentation.intentions/0.1",d["SPECIALISTS"][1]["provider"],"instrumentation specialist dynamically advertised"

health1=session~handle("show NotNotes health and metrics")
call assertEq "SUCCESS",health1["STATUS"],"read-only NotNotes instrumentation request"
call assertEq "GET_NOTNOTES_INSTRUMENTATION",health1["INTENTION"],"instrumentation intention"
call assertEq "INSTRUMENTATION",health1["AUTHORITY"],"instrumentation authority retained"
call assertContains health1["TEXT"],"health=HEALTHY","current NotNotes health"
docsBefore=metricValue(health1["TEXT"],"notnotes.documents.total")

a=session~handle("get me a report on my TPS reports")
call assertEq "SUCCESS",a["STATUS"],"personal TPS report"
call assertEq "TPS Summary Report",a["REPORT_NAME"],"dynamic report selection"
call assertEq 4,a["COUNT"],"alice TPS rows"
call assertContains a["TEXT"],"TPS-2026-102","alice report contains own TPS"
call assertNotContains a["TEXT"],"TPS-2026-101","alice report excludes codex TPS"

b=session~handle("log business TPS cover sheet chased from accounts")
call assertEq "SUCCESS",b["STATUS"],"business log"
call assertContains b["DOCUMENT_KEY"],"BL-","business log key"

health2=session~handle("how is NotNotes doing; show its telemetry")
call assertEq "SUCCESS",health2["STATUS"],"fresh instrumentation after domain mutation"
docsAfter=metricValue(health2["TEXT"],"notnotes.documents.total")
call assertTrue docsAfter > docsBefore,"fresh specialist discovery observes newly created business document"

c=session~handle("show me the TPS review reports")
call assertEq "SUCCESS",c["STATUS"],"review saved report"
call assertEq "TPS Report Review Summary",c["REPORT_NAME"],"review report dynamically selected"

/* Prove discovery is not startup-only: install a saved report after the session
 * exists and use it immediately on the next chat turn. */
columns=.Array~new
col=.Directory~new; col["LABEL"]="TPS Number"; col["BINDING"]="TPSNumber"; columns~append(col)
col=.Directory~new; col["LABEL"]="Cost"; col["BINDING"]="Cost"; columns~append(col)
totals=.Array~of("Cost")
ignore=session~app~installReportDefinition("TPS Cost Audit","TPS Report",columns,totals)
genBefore=session~discoveryGeneration
dyn=session~handle("run the TPS Cost Audit report")
call assertEq "SUCCESS",dyn["STATUS"],"new live report usable next turn"
call assertEq "TPS Cost Audit",dyn["REPORT_NAME"],"dynamic report identity"
call assertTrue session~discoveryGeneration > genBefore,"discovery generation advanced on next turn"

reports=session~handle("what reports are available")
call assertEq "SUCCESS",reports["STATUS"],"live semantic report listing"
call assertEq "LIST_REPORTS",reports["INTENTION"],"report listing intention"
call assertContains reports["TEXT"],"TPS Cost Audit","report listing sees report installed after session start"

cap=session~handle("what can I do with " || b["DOCUMENT_KEY"])
call assertEq "SUCCESS",cap["STATUS"],"semantic action interrogation"
call assertEq "SEMANTIC_DOCUMENT_ACTIONS",cap["INTENTION"],"semantic action intention"
call assertContains cap["TEXT"],"SUBMIT: AVAILABLE","draft business log exposes live submit feasibility"
call assertContains cap["TEXT"],"APPROVE: INFEASIBLE","draft business log keeps understood-but-infeasible approve"

why=session~handle("can I approve " || b["DOCUMENT_KEY"])
call assertEq "SUCCESS",why["STATUS"],"specific infeasible action remains understood"
call assertContains why["TEXT"],"Document is not pending approval","NotNotes supplies feasibility reason"

/* Management-review semantics are exercised in the same end-to-end session;
 * this avoids a second consumer implementation and proves the current live
 * NotNotes relationship graph remains available alongside the support flows. */
mr=session~handle("show the Management Review Selection Report")
call assertEq "SUCCESS",mr["STATUS"],"management selection report"
call assertEq "Management Review Selection Report",mr["REPORT_NAME"],"selection report identity"
call assertEq 12,mr["COUNT"],"selection report contains all twelve TPS links"
call assertContains mr["TEXT"],"MRS-0001","selection report resolves management selection"

mc=session~handle("show the Report by the Management Consultants")
call assertEq "SUCCESS",mc["STATUS"],"management consultant report"
call assertEq "Report by the Management Consultants",mc["REPORT_NAME"],"consultant report identity"
call assertContains mc["TEXT"],"TAMC-0001","consultant report linked time and motion consultant"
call assertContains mc["TEXT"],"SC-0001","consultant report linked synergy consultant"

linked=session~handle("what did the consultants find about TPS-2026-102 and what did they recommend?")
call assertEq "SUCCESS",linked["STATUS"],"linked finding traversal"
call assertEq "LINKED_TPS_EVIDENCE",linked["INTENTION"],"linked evidence intention"
call assertContains linked["TEXT"],"MCF-0002","finding document resolved"
call assertContains linked["TEXT"],"800.00 belongs to alice","finding content resolved"
call assertContains linked["TEXT"],"Record process category","recommended action resolved"

before=session~app~tpsDocuments~items
close=session~close
call assertEq "SUCCESS",close["RATING"],"session rating"
call assertContains close["TPS_KEY"],"TR-","session TPS report"
call assertContains close["REVIEW_KEY"],"TRR-","session review"
call assertEq before+1,session~app~tpsDocuments~items,"TPS report written at session close"
review=session~app~byKey(close["REVIEW_KEY"])
call assertEq close["TPS_KEY"],review~field("TheTPSReport")~string,"review links to session TPS report"
call assertEq "SUCCESS",review~field("TheRating")~string,"review records TPS process success"

/* The next Help Desk session discovers the previous session's TPS process as
 * ordinary live NotNotes data; there is no separate audit store. */
session2=.InitechHelpDeskSession~new(dataRoot,"alice")
h=session2~handle("show my successful Help Desk TPS processes")
call assertEq "SUCCESS",h["STATUS"],"future session finds successful help-desk TPS process"
call assertEq "HELPDESK_TPS_PROCESS_HISTORY",h["INTENTION"],"history intention"
call assertContains h["TEXT"],close["TPS_NUMBER"],"history contains prior session TPS number"

detail=session2~handle("what happened in " || close["TPS_NUMBER"])
call assertEq "SUCCESS",detail["STATUS"],"specific help-desk TPS process review"
call assertContains detail["TEXT"],close["REVIEW_KEY"],"specific process resolves linked review"
call assertContains detail["TEXT"],"Help-desk TPS process SUCCESS","specific process returns review evidence"

/* Failure semantics are part of the same end-to-end qualification rather than
 * a third long-lived environment process. */
failed=.InitechHelpDeskSession~new(dataRoot,"bob")
unknown=failed~handle("please recalibrate the quantum stapler")
call assertEq "UNKNOWN",unknown["STATUS"],"unknown request remains unknown"
failedClose=failed~close
call assertEq "FAILURE",failedClose["RATING"],"failed session TPS process rating"
failedReview=failed~app~byKey(failedClose["REVIEW_KEY"])
call assertEq "FAILURE",failedReview~field("TheRating")~string,"failure persisted in TPS review"
failedNext=.InitechHelpDeskSession~new(dataRoot,"bob")
failedHistory=failedNext~handle("show my failed Help Desk TPS processes")
call assertEq "SUCCESS",failedHistory["STATUS"],"later session discovers failed process"
call assertContains failedHistory["TEXT"],failedClose["TPS_NUMBER"],"failed history contains prior process"

say "PASS Initech two-tier NotNotes help desk + recursive SUCCESS/FAILURE TPS evidence + live instrumentation specialist"
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
::routine assertNotContains
  use strict arg text,needle,label
  if pos(needle,text)>0 then do; say "FAIL" label "unexpected="needle; raise syntax 88.900 array("test assertion failed:" label); end

::routine metricValue
  use strict arg text,name
  marker=name || "="
  p=pos(marker,text)
  if p=0 then return -1
  rest=substr(text,p+length(marker))
  eol=pos("0a"x,rest)
  if eol>0 then rest=left(rest,eol-1)
  return word(rest,1)

::requires "InitechHelpDesk.cls"
