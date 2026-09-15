context=.ReputationFeedAlchemyContext~new(.nil,.nil)
now=.DateTime~new
claim=.ReputationFeedClaim~new('C1','A1','F1','AIRCRAFT_SAFETY_INCIDENT','Cabin event',now,now,'GB',88,'ASSERTS','ACTIVE','SOURCE','citation',context)
claim~setEventKey('INCIDENT-1'); claim~addSubject('MANUFACTURER','BOEING'); claim~addConcept('CABIN_OPENING'); claim~addAffectedGeography('GB'); claim~seal
engine=.ReputationEventClusterEngine~new(context)
clusters=engine~cluster(.array~of(claim),.ReputationCorroborationPolicy~new(2,70,1,120,.true,context))
h=clusters~hypotheses[1]
evidencePolicy=.ReputationCorroborationEvidencePolicy~new
resolver=.ReputationCorroborationEligibilityResolver~new(context)
assessment=h~corroboration(.ReputationCorroborationPolicy~new(2,70),evidencePolicy)
call assertTrue claim~isA(.AlchemyObject),'claim inherits AlchemyObject'
call assertTrue h~isA(.AlchemyObject),'hypothesis inherits AlchemyObject'
call assertTrue engine~isA(.AlchemyObject),'cluster engine inherits AlchemyObject'
call assertTrue evidencePolicy~isA(.AlchemyObject),'provenance evidence policy inherits AlchemyObject'
call assertTrue resolver~isA(.AlchemyObject),'provenance eligibility resolver inherits AlchemyObject'
call assertTrue .AlchemyAdoptionVerifier~verify(evidencePolicy,'STANDARD')~ok,'provenance policy satisfies Alchemy v0.8 STANDARD adoption'
call assertEqual 1,engine~alchemyMetrics['use_count'],'cluster touches inherited telemetry'
call assertEqual 'CORROBORATING',assessment~status,'one-family threshold evidence retained'
adoption=.AlchemyAdoptionVerifier~verify(claim,'STANDARD')
call assertTrue adoption~ok,'claim satisfies Alchemy v0.8 STANDARD adoption'
call assertEqual '0.8', adoption~evidence['base_version'],'Alchemy base version retained'
call assertEqual 'C1',claim~claimId,'claim id retained'
call assertEqual 'F1',claim~familyId,'lineage family retained'
call assertEqual 'INCIDENT-1',claim~eventKey,'normalized event key retained'
say 'PASS test_reputation_feed_event_alchemy_base base=0.8 api=' || .ReputationFeedBuild~API_VERSION
exit 0
assertTrue: procedure; use arg v,l; if v \== .true then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationFeed.cls'
::requires 'AlchemyAdoption.cls'
