/* Reputation Feed v0.12 policy topology / progressive rollout demonstration. */
now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(60)
rolloutStart=now+.InstitutionalPolicyTime~seconds(10)
rolloutEnd=now+.InstitutionalPolicyTime~seconds(600)
policyId='REPUTATION-FEED-GLOBAL'; actor='FEED_RELEASE'
profile=.InstitutionalPolicyAuthorityProfile~new('RF-DEMO-GOV','1.0',start,.nil)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('RF-DEMO-DEPLOY',actor,'DEPLOY',policyId,start,.nil,'REPUTATION_BOARD','AUTH:RF-DEMO-DEPLOY')~seal)
ignored=profile~seal
catalog=.InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.nil,.nil,.InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile))
bridge=.ReputationFeedInstitutionalPolicyBridge~new(policyId)
v1=bridge~newRelease('1.0',policySet('NORMAL',2,70)~seal,start,.nil,'AUTHOR','BOARD','')
v2=bridge~newRelease('2.0',policySet('HEIGHTENED',3,85)~seal,rolloutStart,.nil,'AUTHOR','BOARD','1.0')
ignored=catalog~publish(v1)
rollout=.InstitutionalPolicyProgressiveRequest~new('RF-DEMO-ROLLOUT',v1,v2,actor,rolloutEnd,'bounded reviewed Feed canary','RF-DEMO-CHANGE',now)
ignored=catalog~publish(v2,.nil,rollout)
global=.InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
pilot=.InstitutionalPolicyDeploymentScope~new('GB-PILOT','REPUTATION_FEED','GB','WEB','*','PILOT')~seal
call deploy catalog,v1,'V1-ACTIVE',global,'ACTIVE',start,actor,start
call deploy catalog,v2,'V2-STAGED',global,'STAGED',rolloutStart,actor,now
call deploy catalog,v2,'V2-PILOT',pilot,'CANARY',rolloutStart,actor,now
normalPoint=.InstitutionalPolicyDeploymentPoint~new('REPUTATION_FEED','GB','WEB','PUBLIC','GENERAL')
pilotPoint=.InstitutionalPolicyDeploymentPoint~new('REPUTATION_FEED','GB','WEB','PUBLIC','PILOT')
h=hypothesis()
during=rolloutStart+.InstitutionalPolicyTime~seconds(5)
normal=bridge~operativeForContext(catalog,normalPoint,during)~value~corroborate(h)
pilotOut=bridge~operativeForContext(catalog,pilotPoint,during)~value~corroborate(h)
cut=rolloutStart+.InstitutionalPolicyTime~seconds(20)
call deploy catalog,v2,'V2-ACTIVE',global,'ACTIVE',cut,actor,now
cutOut=bridge~operativeForContext(catalog,normalPoint,cut+.InstitutionalPolicyTime~seconds(1))~value~corroborate(h)
rollback=cut+.InstitutionalPolicyTime~seconds(20)
call deploy catalog,v1,'V1-ROLLBACK',global,'ACTIVE',rollback,actor,now
rollbackOut=bridge~operativeForContext(catalog,normalPoint,rollback+.InstitutionalPolicyTime~seconds(1))~value~corroborate(h)
say 'api=' .ReputationFeedBuild~API_VERSION
say 'normal='normal~policyVersion normal~domainResult~status 'binding='normal~deploymentBindingId 'rollout='normal~progressiveRolloutId
say 'pilot='pilotOut~policyVersion pilotOut~domainResult~status 'mode='pilotOut~deploymentMode 'binding='pilotOut~deploymentBindingId
say 'cutover='cutOut~policyVersion cutOut~domainResult~status 'binding='cutOut~deploymentBindingId
say 'rollback='rollbackOut~policyVersion rollbackOut~domainResult~status 'binding='rollbackOut~deploymentBindingId
exit 0
policySet: procedure
  use arg id,minFamilies,minConfidence
  return .ReputationFeedPolicySet~new(id,.ReputationLineagePolicy~new(78,2),.ReputationCorroborationPolicy~new(minFamilies,minConfidence,1,180,.true),.ReputationCorroborationEvidencePolicy~new(.true,.true,.false,.false),.ReputationGeographicSaliencePolicy~new)
hypothesis: procedure
  h=.ReputationEventHypothesis~new('H-DEMO','AIRCRAFT_SAFETY_INCIDENT')
  h~addClaim(claim('A','ASSERTION:A',92)); h~addClaim(claim('B','ASSERTION:B',84))
  return h~seal
claim: procedure
  use arg id,root,confidence
  c=.ReputationFeedClaim~new(id,'ART-'id,'PUB-'id,'AIRCRAFT_SAFETY_INCIDENT','Deployment demo claim',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-DEMO'); c~addSubject('MANUFACTURER','BOEING'); c~addConcept('CABIN_OPENING')
  c~addAssertionOrigin(root,'SRC-'id,'PRIMARY_ASSERTION','EVID-'id,'demo assertion root'); c~setSourceAuthentication('VERIFIED','AUTH-'id,.false,'HIST-'id)
  return c~seal
deploy: procedure
  use arg catalog,policy,id,scope,mode,when,actor,requestedAt
  req=.InstitutionalPolicyDeploymentRequest~new(id,policy,actor,scope,mode,when,.nil,'demo deployment','DEMO:'id,requestedAt)
  applied=catalog~applyDeployment(policy~policyId,policy~version,req)
  if applied~ok=.false then do; say 'FAIL deployment' id applied~code; exit 1; end
  return
::requires 'ReputationFeedInstitutionalPolicyBridge.cls'
