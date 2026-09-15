now=.DateTime~new
subject='CUSTOMER:BARBIE'
objectId='OBJECT:BAG-STORE:BARBIE'
objectClass='BAGSTOREACCOUNT'
finding=.SecurityFinding~new('F-DEMO','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','CONCERN',subject,80,now-.TimeSpan~new(0,0,10,0,0),now+.TimeSpan~new(0,0,30,0,0),'prior interaction concern','HARDWORLD')~seal
snap=.SecuritySnapshot~new('SNAP-DEMO',subject,now); snap~addFinding(finding); snap~seal
r=.SecurityPolicyRule~new('REVIEW-PURCHASE',100,'METHOD_INVOCATION','REVIEW_REQUIRED','purchase requires review')
r~requireFinding('RESTRICTED_PRODUCT_MISUSE_POSSIBLE'); r~addCriterion('METHOD','EQ','PURCHASEMOREBAGS'); r~addConstraint('ROUTE_TO_REVIEW'); r~seal
sp=.SecurityPolicyFramework~new('BAG-SECURITY','1',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK'); sp~addRule(r); sp~seal
pp=.PermissionPolicy~new('BAG-PERMISSION','1','DENY',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK')
pp~addRule(.PermissionRule~new('PURCHASE-WHEN-CLEAR',100,'ALLOW',subject,objectId,objectClass,'PURCHASEMOREBAGS','ALLOW','*','')~seal)
pp~addRule(.PermissionRule~new('VIEW-ORDER',100,'ALLOW',subject,objectId,objectClass,'VIEWEXISTINGORDER','ALLOW','*','')~seal); pp~seal
b=.SecurityAccessPermissionsBridge~new
do method over .array~of('PURCHASEMOREBAGS','VIEWEXISTINGORDER')
  a=.SecurityMethodActionFactory~create('DEMO-'||method,subject,objectId,objectClass,method,now,'NORMAL',method)~value; a~seal
  ass=.SecurityEffectEngine~new~evaluate(a,snap,sp)~value
  req=b~permissionRequest('PERM-'||method,ass)~value
  pd=.PermissionAuthority~new~decide(req,pp)~value~decision
  say method 'Security='ass~disposition 'Permission='pd~code
end
say 'Security meaning did not itself grant method authority; exact Permission policy decided execution.'
::requires 'SecurityAccessPermissionsBridge.cls'
