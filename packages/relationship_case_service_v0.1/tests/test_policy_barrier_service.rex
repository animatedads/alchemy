catalog = .FederationBankCasePolicyFixtures~publishedCatalog
service = .RelationshipCaseService~new(catalog)
now = .DateTime~new
p=.directory~new; p["caseId"]="ALAN-SVC"; p["caseType"]="EXTERNAL_PRESSURE"
r=service~handle(.RelationshipCaseServiceEnvelope~new("A-OPEN", "CASE.OPEN", "C1", "COMPLIANCE", p, "ALAN-CORR", "", now))
.RelationshipCaseServiceTestSupport~assertTrue(r~ok, "open restricted external pressure case")
signalEl=.RelationshipCaseElement~new("A-SIGNAL", "EXTERNAL_SIGNAL", "POLITICAL_TRADE_PRESSURE", "TRIGGER", "REPUTATION_FEED", "HYPOTHESIS:ALAN:1", "OBSERVATION_NOT_DECISION", now, "RESTRICTED")
signalEl~addTag("NO_CORE_BANKING_AUTHORITY"); signalEl~addTag("ASSERTION_NOT_PROMOTED_TO_FACT"); signalEl~seal
ap=.directory~new; ap["caseId"]="ALAN-SVC"; ap["element"]=signalEl
r=service~handle(.RelationshipCaseServiceEnvelope~new("A-SIGNAL-CMD", "CASE.ATTACH_ELEMENT", "C1", "COMPLIANCE", ap, "ALAN-CORR", "A-OPEN", now))
.RelationshipCaseServiceTestSupport~assertTrue(r~ok, "attach signal")
/* Move through triage and specialist review. */
do spec over .array~of("START_TRIAGE", "START_SPECIALIST_REVIEW")
  tp=.directory~new; tp["caseId"]="ALAN-SVC"; tp["action"]=spec
  r=service~handle(.RelationshipCaseServiceEnvelope~new("A-"||spec, "CASE.TRANSITION", "C1", "COMPLIANCE", tp, "ALAN-CORR", "", now))
  .RelationshipCaseServiceTestSupport~assertTrue(r~ok, "transition "||spec)
end
tp=.directory~new; tp["caseId"]="ALAN-SVC"; tp["action"]="MARK_ACTION_REQUIRED"
r=service~handle(.RelationshipCaseServiceEnvelope~new("A-ACTION", "CASE.TRANSITION", "C1", "COMPLIANCE", tp, "ALAN-CORR", "", now))
.RelationshipCaseServiceTestSupport~assertTrue(\r~ok, "external signal alone cannot become bank action")
.RelationshipCaseServiceTestSupport~assertEqual("CASE_TRANSITION_REQUIREMENT_MISSING", r~code, "assessment/decision required")
q=.directory~new; q["caseId"]="ALAN-SVC"; q["viewerRole"]="TELLER"
teller=service~handle(.RelationshipCaseServiceEnvelope~new("A-TELLER", "CASE.GET", "T1", "TELLER", q))
.RelationshipCaseServiceTestSupport~assertTrue(teller~ok, "teller gets shell")
.RelationshipCaseServiceTestSupport~assertTrue(teller~value~shellOnly, "teller projection is restricted shell")
q["viewerRole"]="COMPLIANCE"
comp=service~handle(.RelationshipCaseServiceEnvelope~new("A-COMP", "CASE.GET", "C1", "COMPLIANCE", q))
.RelationshipCaseServiceTestSupport~assertTrue(comp~ok, "compliance gets case")
.RelationshipCaseServiceTestSupport~assertTrue(\comp~value~shellOnly, "compliance not shell")
.RelationshipCaseServiceTestSupport~assertEqual(1, comp~value~elements~items, "restricted signal visible to compliance")
say "PASS test_policy_barrier_service"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCaseService.cls"
::requires "InstitutionalPolicy.cls"
