s=.GovernanceFixture~study('UNMANAGED')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-UNMANAGED',s,'2026-08-24',2,'CLOCK'); b~seal
rules=.GovernanceFixture~rules
r=.BrandInterventionGovernanceEngine~new~recommend(b,rules)~value
call assertFalse r~institutionalPolicyManaged,'explicit low-level rules are not operative policy selection'
a=.BrandInterventionGovernanceAuthority~new('OPS-BOARD','HUMAN_REVIEW_BOARD','SERVICE_RECOVERY_GUIDANCE')
positive=.BrandInterventionGovernanceDecision~new('D-UP',r,a,'APPROVE_CONTROLLED_PILOT','GOVERNANCE_DECISION:CHANGE-UNMANAGED','2026-08-24T12:00:00Z')
x=positive~seal
call assertFalse x~ok,'positive exposure decision cannot use unmanaged rules'
call assertEqual 'POSITIVE_DECISION_REQUIRES_OPERATIVE_POLICY_SELECTION',x~code,'policy selection guard'
nochange=.BrandInterventionGovernanceDecision~new('D-HOLD',r,a,'NO_CHANGE','GOVERNANCE_DECISION:HOLD-UNMANAGED','2026-08-24T12:01:00Z')
call assertTrue nochange~seal~ok,'non-expanding no-change decision remains recordable'
say 'PASS test_unmanaged_positive_decision_blocked'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
