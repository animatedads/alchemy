root=.NoSQLServerTestSupport~createBlankDatabase("merchant-ref-remediation")
fed=.FederatedDatabaseEngine~new(root)
instrumentRows=.array~new
rem=.array~new
r1=.MBHedgeRemediationObligation~new("REM-1","H-1","RISK-1","EQ-2","POL-SURV","11:18","12:00")
r1~markAction("ACT-1")
r1~resolve("ACT-1","RISK-2","11:45","ORIGINAL_HEDGE_RESTORED")
rem~append(r1)
r2=.MBHedgeRemediationObligation~new("REM-2","H-2","RISK-9","EQ-7","POL-SURV","12:05","12:30")
r2~markEscalated("12:31","MB-RISK-POLICY-AUTH","REMEDIATION_DEADLINE_EXPIRED")
rem~append(r2)
provider=.MBInstrumentReferenceRelationProvider~new(.DatabaseResult,instrumentRows,"merchant_instrument_lines",.nil,"merchant_hedge_equivalence",rem)
ignore=fed~addEngine(provider)

q=fed~execute("SELECT remediation_id, hedge_id, state, due_by, disposition, escalation_reason FROM merchant_hedge_remediation")
call ok q
call assertEq 2,q~rows~items,"remediation history queryable"

q2=fed~execute("SELECT remediation_id, escalation_authority, escalation_reason FROM merchant_hedge_remediation WHERE state='ESCALATED'")
call ok q2
call assertEq 1,q2~rows~items,"escalated hedge remediation directly queryable"
call assertEq "REM-2",q2~rows[1]["remediation_id"],"correct remediation selected"
call assertEq "REMEDIATION_DEADLINE_EXPIRED",q2~rows[1]["escalation_reason"],"policy escalation reason retained"
rich=.nil
do rr over provider~table("merchant_hedge_remediation")~readRows
  if rr["remediation_id"]="REM-2" then rich=rr
end
if rich==.nil then raise syntax 88.900 array("ASSERT_ROWS","missing rich remediation row")
call assertEq "H-2",rich~origin~hedgeId,"rich row retains remediation object"
call assertEq "RISK-9",rich~origin~triggerAssessmentId,"trigger risk provenance retained"

bad=fed~execute("UPDATE merchant_hedge_remediation SET state='RESOLVED' WHERE remediation_id='REM-2'")
if bad~error=.Error~SUCCESS then raise syntax 88.900 array("ASSERT_READ_ONLY","remediation relation must reject mutation")
ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "PASS test_hedge_remediation_query"
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
