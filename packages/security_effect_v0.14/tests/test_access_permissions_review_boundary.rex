now=.DateTime~new
subject='BARBIE'
objectId='OBJECT:BAG-STORE:BARBIE'
objectClass='BAGSTOREACCOUNT'
store=.SecurityEvidenceStore~new
finding=.SecurityFinding~new('F-BAGS-PERM','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','CONCERN',subject,80,now-.TimeSpan~new(0,0,10,0,0),now+.TimeSpan~new(0,0,30,0,0),'unverified prior interaction evidence','HARDWORLD')~seal
call assertTrue store~recordFinding(finding)~ok,'finding stored'
snap=store~snapshotFor(subject,now)
rule=.SecurityPolicyRule~new('REVIEW-BAGS-METHOD',100,'METHOD_INVOCATION','REVIEW_REQUIRED','restricted-product concern requires review')
rule~requireFinding('RESTRICTED_PRODUCT_MISUSE_POSSIBLE')
rule~addCriterion('METHOD','EQ','PURCHASEMOREBAGS')
rule~addConstraint('ROUTE_TO_REVIEW','ACTION','specialist review')
rule~addUnaffectedAbility('VIEW_EXISTING_ORDER')
rule~seal
securityPolicy=.SecurityPolicyFramework~new('BAG-METHOD-SECURITY','1',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK')
securityPolicy~addRule(rule); securityPolicy~seal
purchaseAction=.SecurityMethodActionFactory~create('BUY-BAGS-METHOD',subject,objectId,objectClass,'PURCHASEMOREBAGS',now,'MEDIUM','BAG_PURCHASE')~value; purchaseAction~seal
purchaseAssessment=.SecurityEffectEngine~new~evaluate(purchaseAction,snap,securityPolicy)~value
call assertEqual 'REVIEW_REQUIRED',purchaseAssessment~disposition,'purchase method requires review'
permPolicy=.PermissionPolicy~new('BAG-METHOD-PERM','1','DENY',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK')
permPolicy~addRule(.PermissionRule~new('ALLOW-PURCHASE-IF-CLEAR',100,'ALLOW',subject,objectId,objectClass,'PURCHASEMOREBAGS','ALLOW','*','')~seal)
permPolicy~addRule(.PermissionRule~new('ALLOW-VIEW',100,'ALLOW',subject,objectId,objectClass,'VIEWEXISTINGORDER','ALLOW','*','')~seal)
permPolicy~seal
bridge=.SecurityAccessPermissionsBridge~new
purchaseReq=bridge~permissionRequest('BAG-PERM-1',purchaseAssessment)~value
purchaseDecision=.PermissionAuthority~new~decide(purchaseReq,permPolicy)
call assertTrue purchaseDecision~value~decision~allowed=.false,'review-required purchase cannot execute'
/* Same evidence does not poison an unaffected method. */
viewAction=.SecurityMethodActionFactory~create('VIEW-BAGS-METHOD',subject,objectId,objectClass,'VIEWEXISTINGORDER',now,'LOW','VIEW_EXISTING_ORDER')~value; viewAction~seal
viewAssessment=.SecurityEffectEngine~new~evaluate(viewAction,snap,securityPolicy)~value
call assertEqual 'ALLOW',viewAssessment~disposition,'unaffected method remains allowed by Bouncer'
viewReq=bridge~permissionRequest('BAG-PERM-2',viewAssessment)~value
viewDecision=.PermissionAuthority~new~decide(viewReq,permPolicy)
call assertTrue viewDecision~value~decision~allowed,'unaffected method retains exact permission'
/* REVIEW_REQUIRED becomes durable work, but referral still is not execution authority. */
refPolicy=.SecurityReviewReferralPolicy~new('SECURITY-REVIEW-REFERRAL','1',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK')
refPolicy~addRule(.SecurityReviewReferralRule~new('REFER-BAG-METHOD',100,'METHOD_INVOCATION','REVIEW_REQUIRED','ROUTE_TO_REVIEW','SECURITY_REVIEW','RESTRICTED')~seal)
refPolicy~seal
refCatalog=.SecurityReviewReferralPolicyCatalog~new; call assertTrue refCatalog~publish(refPolicy)~ok,'referral policy published'
caseService=.RelationshipCaseService~new(.FederationBankCasePolicyFixtures~publishedCatalog)
referralAt=.DateTime~new
ref=.SecurityRelationshipCaseBridge~new~refer(purchaseAssessment,refCatalog,caseService,'SECURITY-SYSTEM','SERVICE',referralAt)
call assertTrue ref~ok,'review case opened'
c=caseService~repository~get(ref~value~caseId)~value
call assertTrue c~hasElement('ASSESSMENT','SECURITY_ASSESSMENT'),'case retains assessment reference'
call assertTrue \c~hasElement('DECISION','*'),'review referral does not fabricate decision authority'
say 'PASS test_access_permissions_review_boundary'
exit 0
assertTrue: procedure; use arg v,l; if v=.false then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestSupport.cls'
::requires 'SecurityAccessPermissionsBridge.cls'
::requires 'SecurityRelationshipCaseBridge.cls'
::requires 'FederationBankCasePolicyFixtures.cls'
