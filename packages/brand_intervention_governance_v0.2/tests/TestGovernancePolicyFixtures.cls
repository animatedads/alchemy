::class GovernancePolicyFixture public
::method selection class
  use arg rules, policyVersion='2.0', selectionId='POLICY-SELECTION-1'
  now=.DateTime~new
  start=now-.InstitutionalPolicyTime~seconds(60)
  finish=now+.InstitutionalPolicyTime~seconds(7200)
  pid='BRAND-INTERVENTION-GOVERNANCE'
  profile=.InstitutionalPolicyAuthorityProfile~new('BRAND-GOV-PROFILE','1.0',start,.nil)
  ignore=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-AUTH','POLICY_AUTHOR','AUTHOR',pid,start,.nil,'POLICY_BOARD','AUTH:G-AUTH')~seal)
  ignore=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-APP','POLICY_APPROVER','APPROVER',pid,start,.nil,'POLICY_BOARD','AUTH:G-APP')~seal)
  ignore=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-PUB','POLICY_RELEASE','PUBLISHER',pid,start,.nil,'POLICY_BOARD','AUTH:G-PUB')~seal)
  ignore=profile~addRule(.InstitutionalPolicyAuthorityRule~new('BRAND-GOV-RULE',pid,.true,'OPTIONAL')~seal)
  ignore=profile~seal
  release=.InstitutionalPolicyRelease~new(pid,policyVersion,start,finish,'POLICY_AUTHOR','POLICY_APPROVER','',rules)~seal
  evaluator=.InstitutionalPolicyAuthorityEvaluator~new(profile)
  catalog=.InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,evaluator)
  request=.InstitutionalPolicyPublicationRequest~new(release,'POLICY_RELEASE',now)
  published=catalog~publish(release,request)
  if \published~ok then return .BrandInterventionGovernanceResult~failure('POLICY_FIXTURE_PUBLICATION_FAILED',published~code||':'||published~detail)
  return .BrandInterventionGovernancePolicySelection~fromCatalog(catalog,pid,now,.nil,selectionId)

::method futureSelectionFailure class
  use arg rules
  now=.DateTime~new
  start=now+.InstitutionalPolicyTime~seconds(3600)
  finish=start+.InstitutionalPolicyTime~seconds(7200)
  pid='BRAND-INTERVENTION-GOVERNANCE'
  release=.InstitutionalPolicyRelease~new(pid,'FUTURE',start,finish,'POLICY_AUTHOR','POLICY_APPROVER','',rules)~seal
  catalog=.InstitutionalPolicyCatalog~new
  published=catalog~publish(release)
  if \published~ok then return .BrandInterventionGovernanceResult~failure('POLICY_FIXTURE_PUBLICATION_FAILED',published~code||':'||published~detail)
  return .BrandInterventionGovernancePolicySelection~fromCatalog(catalog,pid,now,.nil,'FUTURE-SELECTION')

::requires 'InstitutionalPolicy.cls'
::requires 'BrandInterventionGovernance.cls'
