now = .DateTime~new
cut = now + .TimeSpan~new(0,0,30,0,0)

v1Set = .ReputationFeedPolicySet~new('NORMAL', -
  .ReputationLineagePolicy~new(78,2), -
  .ReputationCorroborationPolicy~new(2,70,1,180,.true), -
  .ReputationCorroborationEvidencePolicy~new(.true,.true,.false,.false), -
  .ReputationGeographicSaliencePolicy~new(2,5,3,10))~seal

v2Set = .ReputationFeedPolicySet~new('HEIGHTENED', -
  .ReputationLineagePolicy~new(85,3), -
  .ReputationCorroborationPolicy~new(3,85,1,90,.true), -
  .ReputationCorroborationEvidencePolicy~new(.false,.false,.false,.false), -
  .ReputationGeographicSaliencePolicy~new(3,6,4,12))~seal

call assertTrue v1Set~publicationEligible, 'v1 policy set publication eligible when sealed'
call assertTrue v2Set~publicationEligible, 'v2 policy set publication eligible when sealed'
call assertTrue v1Set~semanticIdentity <> v2Set~semanticIdentity, 'material rule change changes policy-set identity'
setAdoption = .AlchemyAdoptionVerifier~verify(v1Set,'STANDARD')
call assertTrue setAdoption~ok, 'policy set satisfies Alchemy v0.8 STANDARD adoption'

bridge = .ReputationFeedInstitutionalPolicyBridge~new('REPUTATION-FEED-GLOBAL')
bridgeAdoption = .AlchemyAdoptionVerifier~verify(bridge,'STANDARD'); call assertTrue bridgeAdoption~ok, 'institutional bridge satisfies Alchemy v0.8 STANDARD adoption'
r1 = bridge~newRelease('1.0',v1Set,now - .TimeSpan~new(0,1,0,0,0),cut,'FEED_POLICY_AUTHOR','REPUTATION_REVIEW_BOARD','')
r2 = bridge~newRelease('2.0',v2Set,cut,.nil,'FEED_POLICY_AUTHOR','REPUTATION_REVIEW_BOARD','1.0')

catalog = .InstitutionalPolicyCatalog~new
pub1 = catalog~publish(r1); call assertTrue pub1~ok, 'publish v1'
pub2 = catalog~publish(r2); call assertTrue pub2~ok, 'publish exact handover v2'

verified = makeClaim('V','ASSERTION:V',91,'VERIFIED')
unverified = makeClaim('U','ASSERTION:U',81,'UNVERIFIED')
h = .ReputationEventHypothesis~new('H-GOV','AIRCRAFT_SAFETY_INCIDENT')
h~addClaim(verified); h~addClaim(unverified); h~seal

opBefore = bridge~operative(catalog,now); call assertTrue opBefore~ok, 'resolve operative v1 before cut'
outBefore = opBefore~value~corroborate(h)
execAdoption = .AlchemyAdoptionVerifier~verify(opBefore~value,'STANDARD'); call assertTrue execAdoption~ok, 'policy execution satisfies Alchemy v0.8 STANDARD adoption'
outAdoption = .AlchemyAdoptionVerifier~verify(outBefore,'STANDARD'); call assertTrue outAdoption~ok, 'governed outcome satisfies Alchemy v0.8 STANDARD adoption'
call assertEqual '1.0',outBefore~policyVersion,'v1 policy version before cut'
call assertEqual 'OPERATIVE',outBefore~evaluationMode,'operative mode retained'
call assertEqual 'IDENTIFIER_ONLY',outBefore~assuranceMode,'no authority evaluator is not overstated'
call assertEqual 'CORROBORATED',outBefore~domainResult~status,'v1 permits unverified second family and threshold two'
call assertEqual 2,outBefore~domainResult~eligibleIndependentFamilyCount,'v1 has two eligible families'
call assertTrue pos('POLICY=REPUTATION-FEED-GLOBAL@1.0',outBefore~canonicalText) > 0,'outcome binds exact policy reference'

opAfter = bridge~operative(catalog,cut); call assertTrue opAfter~ok, 'resolve operative v2 at exact cut'
outAfter = opAfter~value~corroborate(h)
call assertEqual '2.0',outAfter~policyVersion,'v2 owns exact boundary'
call assertEqual 'CORROBORATING',outAfter~domainResult~status,'v2 strict provenance and threshold change outcome'
call assertEqual 1,outAfter~domainResult~eligibleIndependentFamilyCount,'unverified family discovery-only under v2'
call assertEqual 'ORIGIN_UNVERIFIED',outAfter~domainResult~evidenceStatusForClaim('U')~reasonCode,'strict provenance reason retained'

opReplay = bridge~operative(catalog,now); call assertTrue opReplay~ok,'historical replay still resolves v1 after v2 published'
replay = opReplay~value~corroborate(h)
call assertEqual outBefore~canonicalText,replay~canonicalText,'operative historical replay deterministic'

cf = bridge~counterfactual(catalog,'2.0',now); call assertTrue cf~ok,'counterfactual v2 resolved at old time'
cfOut = cf~value~corroborate(h)
call assertEqual 'COUNTERFACTUAL',cfOut~evaluationMode,'counterfactual mode explicit'
call assertEqual '2.0',cfOut~policyVersion,'counterfactual exact version retained'
call assertEqual 'CORROBORATING',cfOut~domainResult~status,'counterfactual applies v2 semantics without rewriting history'

salience = .ReputationGeographicSalienceEvidence~new('H-GOV','GB',now,2,4,1,2,.false,90)
s1 = opBefore~value~assessGeographicSalience(salience)
s2 = opAfter~value~assessGeographicSalience(salience)
call assertEqual 'MEDIUM',s1~domainResult~band,'v1 salience policy classifies medium'
call assertEqual 'LOW',s2~domainResult~band,'v2 salience threshold changes classification'

record = catalog~publicationRecord('REPUTATION-FEED-GLOBAL','1.0')
call assertTrue record~ok,'publication record retained'
call assertEqual r1~semanticIdentity,record~value~policyIdentity,'publication record binds exact release identity'
call assertEqual v1Set~semanticIdentity,r1~payloadIdentity,'release binds exact Feed policy-set identity'

say 'PASS test_institutional_policy_governance before='outBefore~domainResult~status 'after='outAfter~domainResult~status 'counterfactual='cfOut~domainResult~status
exit 0

makeClaim: procedure
  use arg id,root,confidence,authState
  c=.ReputationFeedClaim~new(id,'ART-'id,'PUB-'id,'AIRCRAFT_SAFETY_INCIDENT','Synthetic governed policy claim',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-GOV')
  c~addSubject('MANUFACTURER','BOEING')
  c~addConcept('CABIN_OPENING')
  c~addAssertionOrigin(root,'SRC-'id,'PRIMARY_ASSERTION','EVID-'id,'governance test root')
  c~setSourceAuthentication(authState,'AUTH-'id,.false,'HIST-'id)
  c~seal
  return c

assertTrue: procedure
  use arg value,label
  if value \== .true then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'AlchemyAdoption.cls'
::requires 'ReputationFeedInstitutionalPolicyBridge.cls'
