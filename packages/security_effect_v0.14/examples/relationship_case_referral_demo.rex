now=.DateTime~new
subject='BARBIE'
store=.SecurityEvidenceStore~new
f=.SecurityFinding~new('F-DEMO-BAGS','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','CONCERN',subject,80,now-.TimeSpan~new(0,0,10,0,0),now+.TimeSpan~new(0,0,1,0,0),'prior interaction concern','HARDWORLD')~seal
store~recordFinding(f)
ass=.SecurityEffectEngine~new~evaluate(.SecurityActionSurface~new('A-DEMO-BAGS',subject,'PURCHASE_MORE_BAGS',now,'MEDIUM','BAG_PURCHASE')~seal,store~snapshotFor(subject,now),.SecurityTestSupport~basePolicy(now))~value
rp=.SecurityReviewReferralPolicy~new('SECURITY-REVIEW-REFERRAL','1',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY_DESIGN','RISK_COMMITTEE')
rp~addRule(.SecurityReviewReferralRule~new('REF-BAGS',100,'PURCHASE_MORE_BAGS','REVIEW_REQUIRED','ROUTE_TO_REVIEW','SECURITY_REVIEW','RESTRICTED')~seal); rp~seal
rc=.SecurityReviewReferralPolicyCatalog~new; rc~publish(rp)
svc=.RelationshipCaseService~new(.FederationBankCasePolicyFixtures~publishedCatalog)
rr=.SecurityRelationshipCaseBridge~new~refer(ass,rc,svc,'SECURITY-SYSTEM','SERVICE')
say 'Bouncer disposition:' ass~disposition
say 'Referral result:' rr~ok rr~detail
say 'Relationship case:' rr~value~caseId
say 'Case elements:' svc~repository~get(rr~value~caseId)~value~elements~items
say 'No account-control authority is created by referral.'
exit 0
::requires 'TestSupport.cls'
::requires 'SecurityRelationshipCaseBridge.cls'
::requires 'FederationBankCasePolicyFixtures.cls'
