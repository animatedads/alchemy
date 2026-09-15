root=.NoSQLServerTestSupport~createBlankDatabase("merchant-ref-remediation-execution")
fed=.FederatedDatabaseEngine~new(root)
instrumentRows=.array~new
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"NEUTRALISE_EXISTING_HEDGE","H-1",100,"","neutralise"))
steps~append(.MBHedgeRemediationPlanStep~new("S2",2,"ADD_REPLACEMENT_HEDGE","",-100,"RES-X","replace"))
p=.MBHedgeRemediationPlan~new("PLAN-X","REM-X","ROOT-X","BOOK-B","MAKER","POL-X","12:00",steps)
p~acceptProjection(0,0,100); p~markApproved("APR-X","CHECKER","12:01","AUTH-C")
p~markExecutionStarted("12:02"); p~markExecutionEvidenceComplete("12:03"); p~markExecutionVerified("VER-X","BOOK-A","STEP_OBJECT_DEVIATION","12:04",-100,-100)
plans=.array~new; plans~append(p)
execRows=.array~new
execRows~append(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-X1","PLAN-X","S1",1,"COMPLETED","MERCHANT-TRADING","FILL-X","AUTH-X","H-WRONG",-100,"12:02","POL-X","wrong-way observed"))
execRows~append(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-X2","PLAN-X","S2",2,"COMPLETED","MERCHANT-TRADING","FILL-Y","AUTH-Y","H-NEW",-100,"12:03","POL-X"))
verRows=.array~new
verRows~append(.MBHedgeRemediationPlanExecutionVerification~new("VER-X","PLAN-X","BOOK-A","12:04","STEP_OBJECT_DEVIATION",0,-100,-100,2,2,0,0,0,1,1,.false,.false,"wrong contractual leg"))
provider=.MBInstrumentReferenceRelationProvider~new(.DatabaseResult,instrumentRows,"merchant_instrument_lines",.nil,"merchant_hedge_equivalence",.nil,"merchant_hedge_remediation",.nil,"merchant_cfd_hedge_book",.nil,"merchant_instrument_attestations",.nil,"merchant_market_structure_events",plans,"merchant_hedge_remediation_plans",execRows,"merchant_hedge_remediation_plan_execution",verRows,"merchant_hedge_remediation_plan_verifications")
ignore=fed~addEngine(provider)
q=fed~execute("SELECT evidence_id, plan_id, step_id, execution_state, actual_object_ref, observed_signed_base_exposure_delta, source_authority FROM merchant_hedge_remediation_plan_execution WHERE plan_id='PLAN-X'")
call ok q
call assertEq 2,q~rows~items,"execution evidence rows queryable"
call assertEq "H-WRONG",q~rows[1]["actual_object_ref"],"actual execution object retained"
call assertEq -100,q~rows[1]["observed_signed_base_exposure_delta"],"actual signed delta retained"
vq=fed~execute("SELECT verification_id, result_state, expected_net_base_exposure, actual_net_base_exposure, object_semantic_deviation_count FROM merchant_hedge_remediation_plan_verifications WHERE plan_id='PLAN-X'")
call ok vq
call assertEq "STEP_OBJECT_DEVIATION",vq~rows[1]["result_state"],"verification outcome queryable"
call assertEq 1,vq~rows[1]["object_semantic_deviation_count"],"semantic deviation count retained"
pq=fed~execute("SELECT plan_id, state, verification_state, actual_net_base_exposure, projection_deviation FROM merchant_hedge_remediation_plans WHERE plan_id='PLAN-X'")
call ok pq
call assertEq "DEVIATED",pq~rows[1]["state"],"plan execution state visible"
call assertEq "STEP_OBJECT_DEVIATION",pq~rows[1]["verification_state"],"plan links final verification state"
rich=provider~table("merchant_hedge_remediation_plan_execution")~readRows[1]
call assertEq "EX-X1",rich~origin~evidenceId,"rich row retains original execution evidence object"
bad=fed~execute("UPDATE merchant_hedge_remediation_plan_execution SET execution_state='COMPLETED' WHERE evidence_id='EX-X1'")
if bad~error=.Error~SUCCESS then raise syntax 88.900 array("ASSERT_READ_ONLY","execution evidence relation must reject mutation")
ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "PASS test_remediation_execution_query"
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
