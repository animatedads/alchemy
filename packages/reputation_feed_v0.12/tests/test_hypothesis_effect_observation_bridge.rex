now=.DateTime~new
policy=.ReputationCorroborationPolicy~new(2,70,1,120,.true)
a=.ReputationFeedClaim~new('A','A','F1','AIRCRAFT_SAFETY_INCIDENT','Base wire',now,now,'US',90,'ASSERTS','ACTIVE','WIRE','wire:A')
a~setEventKey('INCIDENT-A'); a~addSubject('MANUFACTURER','BOEING'); a~addConcept('CABIN_OPENING'); a~addAffectedGeography('GB'); a~seal
b=.ReputationFeedClaim~new('B','B','F1','AIRCRAFT_SAFETY_INCIDENT','AI rewrite',now,now,'GB',85,'ASSERTS','ACTIVE','LOCAL','local:B')
b~setEventKey('INCIDENT-A'); b~addSubject('MANUFACTURER','BOEING'); b~addConcept('CABIN_OPENING'); b~addAffectedGeography('GB'); b~seal
c=.ReputationFeedClaim~new('C','C','F2','AIRCRAFT_SAFETY_INCIDENT','Independent',now,now,'GB',80,'ASSERTS','ACTIVE','OTHER','other:C')
c~setEventKey('INCIDENT-A'); c~addSubject('MANUFACTURER','BOEING'); c~addConcept('CABIN_OPENING'); c~addAffectedGeography('GB'); c~seal
h=.ReputationEventHypothesis~new('H1','AIRCRAFT_SAFETY_INCIDENT'); h~addClaim(a); h~addClaim(b); h~addClaim(c); h~seal
bridge=.ReputationFeedEffectBridge~new
observations=bridge~observationsFromHypothesis('OBS','EVENT-PROPOSAL-1',h,policy)
call assertEqual 2,observations~items,'bridge emits one representative observation per independent assertion family'
call assertEqual 'F1',observations[1]~sourceAnchor~metadata['lineage_family'],'first observation retains lineage family'
call assertEqual 'F2',observations[2]~sourceAnchor~metadata['lineage_family'],'second observation retains independent lineage family'
call assertEqual 'GB',observations[1]~affectedGeographyId,'affected geography retained'
call assertEqual 'REPUTATION_FEED_CLAIM',observations[1]~sourceAnchor~sourceKind,'feed claim evidence explicitly typed'

single=.ReputationEventHypothesis~new('H-SINGLE','AIRCRAFT_SAFETY_INCIDENT'); single~addClaim(a); single~seal
blocked=bridge~observationsFromHypothesis('BLOCK','EVENT-PROPOSAL-2',single,policy)
call assertEqual 0,blocked~items,'uncorroborated hypothesis does not promote by default'
override=bridge~observationsFromHypothesis('OVERRIDE','EVENT-PROPOSAL-2',single,policy,.false)
call assertEqual 1,override~items,'explicit caller override can retain an unverified observation when required'


failed=.ReputationFeedClaim~new('FAILED','FAILED','F3','AIRCRAFT_SAFETY_INCIDENT','Failed origin family',now,now,'GB',99,'ASSERTS','ACTIVE','SPOOF','spoof:failed')
failed~setEventKey('INCIDENT-A'); failed~addSubject('MANUFACTURER','BOEING'); failed~addConcept('CABIN_OPENING'); failed~addAffectedGeography('GB'); failed~setSourceAuthentication('FAILED','AUTH-FAILED'); failed~seal
withFailed=.ReputationEventHypothesis~new('H-WITH-FAILED','AIRCRAFT_SAFETY_INCIDENT'); withFailed~addClaim(a); withFailed~addClaim(c); withFailed~addClaim(failed); withFailed~seal
filtered=bridge~observationsFromHypothesis('FILTER','EVENT-PROPOSAL-3',withFailed,policy)
call assertEqual 2,filtered~items,'failed-origin family is retained in hypothesis but not promoted to Effect by default'
call assertEqual 'F1',filtered[1]~sourceAnchor~metadata['lineage_family'],'eligible first family promoted'
call assertEqual 'F2',filtered[2]~sourceAnchor~metadata['lineage_family'],'eligible second family promoted'
call assertEqual 'UNASSESSED',filtered[1]~sourceAnchor~metadata['source_authentication_state'],'provenance metadata retained on Effect anchor'
permissive=.ReputationCorroborationEvidencePolicy~new(.true,.true,.true,.true)
permitted=bridge~observationsFromHypothesis('PERMIT','EVENT-PROPOSAL-3',withFailed,policy,.true,permissive)
call assertEqual 3,permitted~items,'explicit provenance policy may promote failed-origin family'

/* Different publication families can still descend from one underlying assertion.
   Once an independent FAA confirmation makes the hypothesis corroborated, Effect
   must receive one representative per assertion root, not one per masthead. */
r=.ReputationFeedClaim~new('AR','AR','PUB-REUTERS','AIRCRAFT_SAFETY_INCIDENT','Reuters paraphrase',now,now,'GB',92,'ASSERTS','ACTIVE','REUTERS','r')
r~setEventKey('INCIDENT-ANCESTRY'); r~addConcept('CABIN_OPENING'); r~addAffectedGeography('GB'); r~addAssertionOrigin('BOEING-PR-123','BOEING','DERIVED_FROM','LIB-R'); r~seal
d=.ReputationFeedClaim~new('AD','AD','PUB-BBC','AIRCRAFT_SAFETY_INCIDENT','BBC paraphrase',now,now,'GB',88,'ASSERTS','ACTIVE','BBC','d')
d~setEventKey('INCIDENT-ANCESTRY'); d~addConcept('CABIN_OPENING'); d~addAffectedGeography('GB'); d~addAssertionOrigin('BOEING-PR-123','BOEING','QUOTED_ASSERTION','LIB-D'); d~seal
f=.ReputationFeedClaim~new('AF','AF','PUB-FAA','AIRCRAFT_SAFETY_INCIDENT','FAA confirmation',now,now,'GB',84,'ASSERTS','ACTIVE','FAA','f')
f~setEventKey('INCIDENT-ANCESTRY'); f~addConcept('CABIN_OPENING'); f~addAffectedGeography('GB'); f~addAssertionOrigin('FAA-CONFIRM-987','FAA','PRIMARY_CONFIRMATION','LIB-F'); f~seal
ancestryH=.ReputationEventHypothesis~new('H-ANCESTRY','AIRCRAFT_SAFETY_INCIDENT'); ancestryH~addClaim(r); ancestryH~addClaim(d); ancestryH~addClaim(f); ancestryH~seal
ancestryObs=bridge~observationsFromHypothesis('ANCESTRY','EVENT-PROPOSAL-4',ancestryH,policy)
call assertEqual 2,ancestryObs~items,'Effect bridge emits one observation per underlying assertion root'
call assertEqual 'BOEING-PR-123',ancestryObs[1]~sourceAnchor~metadata['assertion_origin_family'],'Boeing root retained on Effect evidence'
call assertEqual 'ASSERTION:BOEING-PR-123',ancestryObs[1]~sourceAnchor~metadata['corroboration_family'],'effective assertion family retained on Effect evidence'
call assertEqual 'FAA-CONFIRM-987',ancestryObs[2]~sourceAnchor~metadata['assertion_origin_family'],'independent FAA root retained on Effect evidence'

say 'PASS test_hypothesis_effect_observation_bridge observations=' observations~items 'blocked=' blocked~items
exit 0
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
::requires 'ReputationFeedEffectBridge.cls'
