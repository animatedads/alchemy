now = .DateTime~new
cut = now + .TimeSpan~new(0,0,30,0,0)

lenient = .ReputationFeedPolicySet~new('LENIENT', -
  .ReputationLineagePolicy~new(78,2), -
  .ReputationCorroborationPolicy~new(2,70,1,180,.true), -
  .ReputationCorroborationEvidencePolicy~new(.true,.true,.false,.false), -
  .ReputationGeographicSaliencePolicy~new)~seal
strict = .ReputationFeedPolicySet~new('STRICT', -
  .ReputationLineagePolicy~new(85,3), -
  .ReputationCorroborationPolicy~new(3,85,1,90,.true), -
  .ReputationCorroborationEvidencePolicy~new(.false,.false,.false,.false), -
  .ReputationGeographicSaliencePolicy~new)~seal

policyBridge = .ReputationFeedInstitutionalPolicyBridge~new('REPUTATION-FEED-GLOBAL')
r1 = policyBridge~newRelease('1.0',lenient,now - .TimeSpan~new(0,1,0,0,0),cut,'AUTHOR','BOARD','')
r2 = policyBridge~newRelease('2.0',strict,cut,.nil,'AUTHOR','BOARD','1.0')
catalog = .InstitutionalPolicyCatalog~new
call assertTrue catalog~publish(r1)~ok,'publish lenient'
call assertTrue catalog~publish(r2)~ok,'publish strict'

h = .ReputationEventHypothesis~new('H-PROMOTE','AIRCRAFT_SAFETY_INCIDENT')
h~addClaim(makeClaim('A','ASSERTION:A',92,'VERIFIED'))
h~addClaim(makeClaim('B','ASSERTION:B',84,'UNVERIFIED'))
h~seal

operative1 = policyBridge~operative(catalog,now); call assertTrue operative1~ok,'operative v1'
promoter = .ReputationFeedGovernedEffectBridge~new
promotion = promoter~promote('OBS-GOV','EVENT-GOV',h,operative1~value)
call assertTrue promotion~allowed,'corroborated operative policy may promote'
call assertEqual 'OPERATIVE_POLICY_CORROBORATED',promotion~reasonCode,'operative promotion reason'
call assertEqual 2,promotion~observationCount,'one observation per independent assertion root'
call assertTrue .AlchemyAdoptionVerifier~verify(promoter,'STANDARD')~ok,'governed effect bridge Alchemy adoption'
call assertTrue .AlchemyAdoptionVerifier~verify(promotion,'STANDARD')~ok,'governed promotion Alchemy adoption'

do observation over promotion~observations
  metadata = observation~sourceAnchor~metadata
  call assertEqual 'REPUTATION-FEED-GLOBAL@1.0',metadata['feed_policy_ref'],'observation carries exact Feed policy ref'
  call assertEqual r1~semanticIdentity,metadata['feed_policy_identity'],'observation carries exact institutional release identity'
  call assertEqual lenient~semanticIdentity,metadata['feed_policy_set_identity'],'observation carries exact domain policy-set identity'
  call assertEqual 'OPERATIVE',metadata['feed_policy_evaluation_mode'],'observation cannot hide evaluation mode'
  call assertEqual 'IDENTIFIER_ONLY',metadata['feed_policy_assurance'],'observation does not overstate publication authority assurance'
end

operative2 = policyBridge~operative(catalog,cut); call assertTrue operative2~ok,'operative v2'
blocked = promoter~promote('OBS-STRICT','EVENT-GOV',h,operative2~value)
call assertFalse blocked~allowed,'strict operative policy blocks non-corroborated hypothesis'
call assertEqual 0,blocked~observationCount,'blocked hypothesis creates no Effect observations'
call assertEqual 'HYPOTHESIS_NOT_CORROBORATED',blocked~reasonCode,'strict-policy block reason retained'

counter = policyBridge~counterfactual(catalog,'1.0',cut); call assertTrue counter~ok,'counterfactual lenient policy'
cf = promoter~promote('OBS-CF','EVENT-GOV',h,counter~value)
call assertFalse cf~allowed,'counterfactual evaluation cannot cross operational Effect boundary'
call assertEqual 0,cf~observationCount,'counterfactual creates no Effect observations'
call assertEqual 'COUNTERFACTUAL_NOT_PROMOTABLE',cf~reasonCode,'counterfactual boundary explicit'
call assertEqual 'COUNTERFACTUAL',cf~governedOutcome~evaluationMode,'blocked promotion retains counterfactual evidence'

say 'PASS test_governed_effect_bridge allowed='promotion~observationCount 'strict='blocked~reasonCode 'counterfactual='cf~reasonCode
exit 0

makeClaim: procedure
  use arg id,root,confidence,authState
  c=.ReputationFeedClaim~new(id,'ART-'id,'PUB-'id,'AIRCRAFT_SAFETY_INCIDENT','Governed promotion claim',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-GOV')
  c~addSubject('MANUFACTURER','BOEING')
  c~addConcept('CABIN_OPENING')
  c~addAffectedGeography('GB')
  c~addAssertionOrigin(root,'SRC-'id,'PRIMARY_ASSERTION','EVID-'id,'governed effect root')
  c~setSourceAuthentication(authState,'AUTH-'id,.false,'HIST-'id)
  c~seal
  return c

assertTrue: procedure
  use arg value,label
  if value \== .true then do; say 'FAIL:' label; exit 1; end
  return
assertFalse: procedure
  use arg value,label
  if value == .true then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'AlchemyAdoption.cls'
::requires 'ReputationFeedGovernedEffectBridge.cls'
