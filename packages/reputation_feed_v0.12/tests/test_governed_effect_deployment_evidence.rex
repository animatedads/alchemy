now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
policyId = 'REPUTATION-FEED-GLOBAL'
actor = 'FEED_PLATFORM_RELEASE'
profile=.InstitutionalPolicyAuthorityProfile~new('RF-EFFECT-DEPLOY-GOV','1.0',start,.nil)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('RF-EFFECT-DEPLOY-GRANT',actor,'DEPLOY',policyId,start,.nil,'REPUTATION_BOARD','AUTH:RF-EFFECT-DEPLOY-GRANT')~seal)
ignored=profile~seal
deployEval=.InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog=.InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.nil,.nil,deployEval)
bridge=.ReputationFeedInstitutionalPolicyBridge~new(policyId)
set=.ReputationFeedPolicySet~new('PROMOTE',.ReputationLineagePolicy~new(78,2),.ReputationCorroborationPolicy~new(2,70,1,180,.true),.ReputationCorroborationEvidencePolicy~new(.true,.true,.false,.false),.ReputationGeographicSaliencePolicy~new)~seal
release=bridge~newRelease('1.0',set,start,.nil,'AUTHOR','BOARD','')
call assertTrue catalog~publish(release)~ok,'publish policy'
pilotScope=.InstitutionalPolicyDeploymentScope~new('RF-GB-PILOT','REPUTATION_FEED','GB','WEB','*','PILOT')~seal
req=.InstitutionalPolicyDeploymentRequest~new('RF-DEP-EFFECT-PILOT',release,actor,pilotScope,'CANARY',now,.nil,'pilot governed Effect promotion','RF-CHG-300',now)
call assertTrue catalog~applyDeployment(policyId,'1.0',req)~ok,'deploy canary'
point=.InstitutionalPolicyDeploymentPoint~new('REPUTATION_FEED','GB','WEB','PUBLIC','PILOT')
execution=bridge~operativeForContext(catalog,point,now + .InstitutionalPolicyTime~seconds(1))
call assertTrue execution~ok,'resolve canary policy execution'

h=.ReputationEventHypothesis~new('H-EFFECT-DEPLOY','AIRCRAFT_SAFETY_INCIDENT')
h~addClaim(makeClaim('A','ASSERTION:A',92)); h~addClaim(makeClaim('B','ASSERTION:B',84)); h~seal
promoter=.ReputationFeedGovernedEffectBridge~new
promotion=promoter~promote('OBS-DEPLOY','EVENT-DEPLOY',h,execution~value)
call assertTrue promotion~allowed,'operative canary policy can promote corroborated evidence'
call assertEqual 2,promotion~observationCount,'independent assertion roots promoted'
do observation over promotion~observations
  meta=observation~sourceAnchor~metadata
  call assertEqual 'CANARY',meta['feed_policy_deployment_mode'],'Effect anchor keeps deployment mode'
  call assertEqual 'TOPOLOGY',meta['feed_policy_deployment_source'],'Effect anchor keeps topology source'
  call assertEqual 'RF-DEP-EFFECT-PILOT',meta['feed_policy_deployment_binding_id'],'Effect anchor keeps exact deployment binding'
  call assertEqual point~semanticIdentity,meta['feed_policy_deployment_point'],'Effect anchor keeps exact deployment point'
  call assertTrue meta['feed_policy_deployment_identity'] <> '','Effect anchor keeps execution deployment identity'
end
say 'PASS test_governed_effect_deployment_evidence observations='promotion~observationCount
exit 0
makeClaim: procedure
  use arg id,root,confidence
  c=.ReputationFeedClaim~new(id,'ART-'id,'PUB-'id,'AIRCRAFT_SAFETY_INCIDENT','Governed deployment promotion claim',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-DEPLOY'); c~addSubject('MANUFACTURER','BOEING'); c~addConcept('CABIN_OPENING'); c~addAffectedGeography('GB')
  c~addAssertionOrigin(root,'SRC-'id,'PRIMARY_ASSERTION','EVID-'id,'governed deployment root')
  c~setSourceAuthentication('VERIFIED','AUTH-'id,.false,'HIST-'id)
  return c~seal
assertTrue: procedure
  use arg value,label
  if value \== .true then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
::requires 'ReputationFeedGovernedEffectBridge.cls'
