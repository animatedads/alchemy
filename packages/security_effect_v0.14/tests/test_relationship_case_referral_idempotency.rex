call addPath
now=.DateTime~new
subject='CUSTOMER-REF-1'
store=.SecurityEvidenceStore~new
call assertTrue store~recordFinding(.SecurityTestSupport~geoFinding(subject,now))~ok,'geo finding'
snap=store~snapshotFor(subject,now)
a=.SecurityActionSurface~new('A-REF-GOLD',subject,'PURCHASE',now,'HIGH','PAYMENT')
a~putAttribute('PAYMENT_INSTRUMENT','STORED'); a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET'); a~putAttribute('AMOUNT',20000); a~seal
ass=.SecurityEffectEngine~new~evaluate(a,snap,.SecurityTestSupport~basePolicy(now))~value
call assertEqual 'HOLD',ass~disposition,'gold hold'
rp=.SecurityReviewReferralPolicy~new('SECURITY-REVIEW-REFERRAL','1',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY_DESIGN','RISK_COMMITTEE')
rp~addRule(.SecurityReviewReferralRule~new('REF-HIGH-VALUE',100,'PURCHASE','HOLD','OUT_OF_BAND_CONFIRMATION_REQUIRED','SECURITY_REVIEW','RESTRICTED')~seal); rp~seal
rc=.SecurityReviewReferralPolicyCatalog~new; call assertTrue rc~publish(rp)~ok,'referral policy publish'
svc=.RelationshipCaseService~new(.FederationBankCasePolicyFixtures~publishedCatalog)
referralAt=.DateTime~new
b=.SecurityRelationshipCaseBridge~new
r1=b~refer(ass,rc,svc,'SECURITY-SYSTEM','SERVICE',referralAt)
call assertTrue r1~ok,'first referral'
r2=b~refer(ass,rc,svc,'SECURITY-SYSTEM','SERVICE',referralAt)
call assertTrue r2~ok,'exact retry succeeds idempotently'
call assertEqual r1~value~caseId,r2~value~caseId,'stable case id'
call assertEqual 'IDEMPOTENT_REPLAY',r2~value~caseReply~code,'open command replay is idempotent'
call assertEqual 3,svc~repository~get(r1~value~caseId)~value~elements~items,'retry did not duplicate references'
safe=.SecurityActionSurface~new('A-SAFE-REF',subject,'READ_BOOKING_STATUS',now,'LOW','BOOKING_STATUS_READ')~seal
safeAss=.SecurityEffectEngine~new~evaluate(safe,snap,.SecurityTestSupport~basePolicy(now))~value
nr=b~refer(safeAss,rc,svc,'SECURITY-SYSTEM','SERVICE',referralAt)
call assertTrue nr~ok,'non-referral evaluation succeeds'
call assertEqual 'NO_REFERRAL',nr~detail,'allow action does not open review case'
call assertEqual '',nr~value~caseId,'no case id for safe action'
say 'PASS test_relationship_case_referral_idempotency'
exit 0
addPath: return
assertTrue: procedure; use arg v,l; if v=.false then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestSupport.cls'
::requires 'SecurityRelationshipCaseBridge.cls'
::requires 'FederationBankCasePolicyFixtures.cls'
