now=.DateTime~new
cut=now+.TimeSpan~new(0,0,30,0,0)

v1=.ReputationFeedPolicySet~new('NORMAL',.ReputationLineagePolicy~new,.ReputationCorroborationPolicy~new(2,70,1,180,.true),.ReputationCorroborationEvidencePolicy~new(.true,.true,.false,.false),.ReputationGeographicSaliencePolicy~new)~seal
v2=.ReputationFeedPolicySet~new('HEIGHTENED',.ReputationLineagePolicy~new,.ReputationCorroborationPolicy~new(3,85,1,90,.true),.ReputationCorroborationEvidencePolicy~new(.false,.false,.false,.false),.ReputationGeographicSaliencePolicy~new(3,6,4,12))~seal
bridge=.ReputationFeedInstitutionalPolicyBridge~new('REPUTATION-FEED-GLOBAL')
r1=bridge~newRelease('1.0',v1,now-.TimeSpan~new(0,1,0,0,0),cut,'AUTHOR','BOARD','')
r2=bridge~newRelease('2.0',v2,cut,.nil,'AUTHOR','BOARD','1.0')
catalog=.InstitutionalPolicyCatalog~new
catalog~publish(r1); catalog~publish(r2)

h=.ReputationEventHypothesis~new('H-DEMO','AIRCRAFT_SAFETY_INCIDENT')
h~addClaim(makeClaim('A','ASSERTION:A',92,'VERIFIED'))
h~addClaim(makeClaim('B','ASSERTION:B',84,'UNVERIFIED'))
h~seal

before=bridge~operative(catalog,now)~value
after=bridge~operative(catalog,cut)~value
counter=bridge~counterfactual(catalog,'1.0',cut)~value
p=.ReputationFeedGovernedEffectBridge~new
pb=p~promote('OBS-BEFORE','EVENT-DEMO',h,before)
pa=p~promote('OBS-AFTER','EVENT-DEMO',h,after)
pc=p~promote('OBS-CF','EVENT-DEMO',h,counter)

say 'api=' .ReputationFeedBuild~API_VERSION
say 'before_policy=' before~executionContext~policy~policyId || '@' || before~executionContext~policy~version
say 'before_status=' pb~governedOutcome~domainResult~status 'effect_observations='pb~observationCount
say 'after_policy=' after~executionContext~policy~policyId || '@' || after~executionContext~policy~version
say 'after_status=' pa~governedOutcome~domainResult~status 'promotion='pa~reasonCode
say 'counterfactual_mode=' pc~governedOutcome~evaluationMode 'promotion='pc~reasonCode
say 'assurance=' pb~governedOutcome~assuranceMode
if pb~observationCount>0 then do
  m=pb~observations[1]~sourceAnchor~metadata
  say 'observation_policy_ref='m['feed_policy_ref']
end
exit 0

makeClaim: procedure
  use arg id,root,confidence,authState
  c=.ReputationFeedClaim~new(id,'ART-'id,'PUB-'id,'AIRCRAFT_SAFETY_INCIDENT','Governed policy demo',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-DEMO'); c~addSubject('MANUFACTURER','BOEING'); c~addConcept('CABIN_OPENING'); c~addAffectedGeography('GB')
  c~addAssertionOrigin(root,'SRC-'id,'PRIMARY_ASSERTION','EVID-'id,'demo')
  c~setSourceAuthentication(authState,'AUTH-'id,.false,'HIST-'id); c~seal
  return c

::requires 'ReputationFeedGovernedEffectBridge.cls'
