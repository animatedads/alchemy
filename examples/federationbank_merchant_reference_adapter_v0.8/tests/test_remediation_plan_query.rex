root=.NoSQLServerTestSupport~createBlankDatabase("merchant-ref-remediation-plan")
fed=.FederatedDatabaseEngine~new(root)
instrumentRows=.array~new
plans=.array~new
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"NEUTRALISE_EXISTING_HEDGE","H-1",100,"","unwind old hedge"))
steps~append(.MBHedgeRemediationPlanStep~new("S2",2,"ADD_REPLACEMENT_HEDGE","",-100,"RES-X","replace hedge"))
p=.MBHedgeRemediationPlan~new("PLAN-1","REM-1","T-ROOT","BOOK-1","MAKER-A","POL-1","12:00",steps)
p~acceptProjection(0,0,100)
p~markApproved("APR-1","CHECKER-B","12:05","AUTH-CHECKER")
plans~append(p)
provider=.MBInstrumentReferenceRelationProvider~new(.DatabaseResult,instrumentRows,"merchant_instrument_lines",.nil,"merchant_hedge_equivalence",.nil,"merchant_hedge_remediation",.nil,"merchant_cfd_hedge_book",.nil,"merchant_instrument_attestations",.nil,"merchant_market_structure_events",plans)
ignore=fed~addEngine(provider)
q=fed~execute("SELECT plan_id, remediation_id, state, projected_net_base_exposure, peak_abs_base_exposure, approved_by, step_count FROM merchant_hedge_remediation_plans WHERE state='APPROVED'")
call ok q
call assertEq 1,q~rows~items,"approved remediation plan queryable"
call assertEq "PLAN-1",q~rows[1]["plan_id"],"plan selected"
call assertEq 0,q~rows[1]["projected_net_base_exposure"],"projected whole-book net retained"
call assertEq 100,q~rows[1]["peak_abs_base_exposure"],"transient exposure retained"
call assertEq "CHECKER-B",q~rows[1]["approved_by"],"maker/checker evidence retained"
call assertEq 2,q~rows[1]["step_count"],"ordered plan steps retained"
rich=provider~table("merchant_hedge_remediation_plans")~readRows[1]
call assertEq "BOOK-1",rich~origin~baselineBookAssessmentId,"rich row retains original plan object"
bad=fed~execute("UPDATE merchant_hedge_remediation_plans SET state='EXECUTED' WHERE plan_id='PLAN-1'")
if bad~error=.Error~SUCCESS then raise syntax 88.900 array("ASSERT_READ_ONLY","remediation plan relation must reject mutation")
ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "PASS test_remediation_plan_query"
exit 0
ok: procedure
  use arg rs
  if rs~status<>.Error~SUCCESS then raise syntax 88.900 array("QUERY_FAILED",rs~status,rs~error,rs~message)
return .true
assertEq: procedure
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
return .true
::requires "NoSQLServer.cls"
::requires "TestSupport.cls"
::requires "FederationBankMerchantBank.cls"
::requires "SourceEvidenceRelationAdapter.cls"
::requires "FederationBankMerchantReferenceAdapter.cls"
