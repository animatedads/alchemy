rules=.GovernanceFixture~rules
selected=.GovernancePolicyFixture~selection(rules,'2.0','SEL-AUTH')
call assertTrue selected~ok,'Institutional Policy resolves operative governance payload'
sel=selected~value
call assertTrue sel~sealed,'selection sealed'
call assertEqual 'BRAND-INTERVENTION-GOVERNANCE',sel~policyId,'exact policy id'
call assertEqual '2.0',sel~policyVersion,'exact policy version'
call assertEqual 'ROLE_AUTHORITY',sel~publicationAssuranceMode,'publication authority assurance preserved'
call assertTrue sel~policyIdentity~length>0,'exact semantic identity retained'
call assertTrue sel~reasoningMaterial~pos('PROFILE_IDENTITY=INSTITUTIONAL-POLICY-AUTHORITY-PROFILE/2')>0,'publication authority evidence retained'

s=.GovernanceFixture~study('POLICY')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-POLICY',s,'2026-08-24',2,'CLOCK'); b~seal
x=.BrandInterventionGovernanceEngine~new~recommendUnderInstitutionalPolicy(b,sel)
call assertTrue x~ok,'managed recommendation succeeds'
r=x~value
call assertTrue r~institutionalPolicyManaged,'recommendation marked policy managed'
mat=r~reasoningMaterial
call assertTrue mat~pos('INSTITUTIONAL_POLICY_MANAGED=1')>0,'managed flag in reasoning'
call assertTrue mat~pos('INSTITUTIONAL_POLICY_VERSION=2.0')>0,'exact selected version in reasoning'
call assertTrue mat~pos('INSTITUTIONAL_POLICY_SELECTION_ACTIVE')>0,'selection rationale preserved'
call assertTrue mat~pos('USE_EXACT_SELECTED_POLICY_VERSION')>0,'exact version condition preserved'
say 'PASS test_institutional_policy_selection'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'TestGovernancePolicyFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
