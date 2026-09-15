call addPath
now = .DateTime~new
subject = 'BARBIE'
store = .SecurityEvidenceStore~new
reportTime = now - .TimeSpan~new(0,0,10,0,0)
f = .SecurityFinding~new('F-BAGS-CASE','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','CONCERN',subject,80,reportTime,now + .TimeSpan~new(0,0,1,0,0),'prior interaction concern','HARDWORLD')~seal
call assertTrue store~recordFinding(f)~ok,'finding stored'
snap = store~snapshotFor(subject,now)
ass = .SecurityEffectEngine~new~evaluate(.SecurityActionSurface~new('A-BAGS-CASE',subject,'PURCHASE_MORE_BAGS',now,'MEDIUM','BAG_PURCHASE')~seal,snap,.SecurityTestSupport~basePolicy(now))~value
call assertEqual 'REVIEW_REQUIRED',ass~disposition,'Bouncer requests review'
refPolicy = .SecurityReviewReferralPolicy~new('SECURITY-REVIEW-REFERRAL','1',now - .TimeSpan~new(0,0,0,1,0),.nil,'SECURITY_DESIGN','RISK_COMMITTEE')
r = .SecurityReviewReferralRule~new('REF-BAGS',100,'PURCHASE_MORE_BAGS','REVIEW_REQUIRED','ROUTE_TO_REVIEW','SECURITY_REVIEW','RESTRICTED')~seal
call assertTrue refPolicy~addRule(r),'referral rule added'
refPolicy~seal
refCatalog = .SecurityReviewReferralPolicyCatalog~new
call assertTrue refCatalog~publish(refPolicy)~ok,'referral policy published'
caseCatalog = .FederationBankCasePolicyFixtures~publishedCatalog
service = .RelationshipCaseService~new(caseCatalog)
referralAt = .DateTime~new
bridge = .SecurityRelationshipCaseBridge~new
referralResult = bridge~refer(ass,refCatalog,service,'SECURITY-SYSTEM','SERVICE',referralAt)
call assertTrue referralResult~ok,'review referral succeeds'
ref = referralResult~value
call assertTrue ref~caseId <> '','case id returned'
caseResult = service~repository~get(ref~caseId)
call assertTrue caseResult~ok,'case exists'
c = caseResult~value
call assertEqual 'SECURITY_REVIEW',c~caseType,'case type comes from fixed referral policy'
call assertEqual 3,c~elements~items,'subject + assessment + referral-policy references attached'
call assertTrue c~hasElement('ASSESSMENT','SECURITY_ASSESSMENT'),'security assessment attached by reference'
call assertTrue c~hasElement('POLICY_REFERENCE','SECURITY_REVIEW_REFERRAL_POLICY'),'referral policy retained by reference'
call assertTrue \c~hasElement('DECISION','*'),'referral does not fabricate case decision authority'
call assertTrue \c~hasElement('ACCOUNT_CONTROL','*'),'referral does not fabricate account-control authority'
p=.directory~new; p['caseId']=c~caseId; p['action']='START_TRIAGE'
reply=service~handle(.RelationshipCaseServiceEnvelope~new('CASE-TRIAGE-1','CASE.TRANSITION','STAFF-1','COMPLIANCE',p,'CASE-CORR','',referralAt))
call assertTrue reply~ok,'triage'
p=.directory~new; p['caseId']=c~caseId; p['action']='START_SPECIALIST_REVIEW'
reply=service~handle(.RelationshipCaseServiceEnvelope~new('CASE-REVIEW-1','CASE.TRANSITION','STAFF-1','COMPLIANCE',p,'CASE-CORR','CASE-TRIAGE-1',referralAt))
call assertTrue reply~ok,'specialist review'
p=.directory~new; p['caseId']=c~caseId; p['action']='MARK_ACTION_REQUIRED'
reply=service~handle(.RelationshipCaseServiceEnvelope~new('CASE-ACTION-1','CASE.TRANSITION','STAFF-1','COMPLIANCE',p,'CASE-CORR','CASE-REVIEW-1',referralAt))
call assertTrue \reply~ok,'security referral alone cannot authorize action-required path'
call assertEqual 'CASE_TRANSITION_REQUIREMENT_MISSING',reply~code,'real authoritative decision still required'
say 'PASS test_relationship_case_referral_integration'
exit 0
addPath: return
assertTrue: procedure; use arg v,l; if v=.false then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestSupport.cls'
::requires 'SecurityRelationshipCaseBridge.cls'
::requires 'FederationBankCasePolicyFixtures.cls'
