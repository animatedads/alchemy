now = .DateTime~new
source = .ReputationSourceIdentity~new('NEWS-COMP','NEWS','Comp Source','GROUP','OWNER','GB','EDITORIAL_REPORTING','comp-feed')
source~seal
envelope = .ReputationRawEnvelope~new('ENV-COMP',source,now,now,'TEXT/PLAIN','https://comp.example/item','EN','1111111111111111111111111111111111111111111111111111111111111111')
envelope~addField('TITLE','Synthetic compromised-source report')
envelope~addField('OBSERVED_GEOGRAPHY','GB')
envelope~addSegment('HEADLINE','Synthetic compromised-source report')
envelope~addSegment('BODY','A synthetic event occurred.')
envelope~seal
acquired = .ReputationNewsPublicationAdapter~new~adapt(envelope)
call assertTrue acquired~accepted,'news envelope acquired'
handoff = acquired~librarianHandoff
finding = .ReputationLibrarianFinding~new('FIND-COMP',handoff~handoffId,'SYNTH_EVENT','Synthetic',now,89,'ASSERTS')
finding~setEventKey('EVENT-COMP')
finding~addParagraphIndex(1)
finding~addConcept('SYNTH'); finding~addAffectedGeography('GB'); finding~seal
verified = .ReputationSourceAuthenticationResult~new('AUTH-COMP','NEWS-COMP','BIND','PROOF','SIPHASH-2-4-128','KEY',now,.true,'VERIFIED','ORIGIN_VERIFIED','origin verified')
history = .ReputationSourceHistoryView~new('NEWS-COMP',now,3,'VERIFIED','BIND','KEY','comp-feed',.true,1,0,0,0,.array~of('AUTHENTICATION','COMPROMISE_DECLARED'))
packet = .ReputationSourceEvidencePacket~new('PACKET-COMP',envelope,verified,history); packet~seal
claim = .ReputationLibrarianClaimBridge~new~claimFromFinding('CLAIM-COMP','FAM-COMP',handoff,finding,'ACTIVE',packet)
call assertEqual 'VERIFIED',claim~sourceAuthenticationState,'verified origin retained'
call assertTrue claim~sourceCompromised,'source-history compromise copied to claim'
call assertTrue claim~sourceHistoryEvidenceId <> '','history evidence identity retained'
call assertEqual 89,claim~confidence,'source compromise does not rewrite Librarian confidence'

clean=.ReputationFeedClaim~new('CLEAN','ART-CLEAN','FAM-CLEAN','SYNTH_EVENT','Synthetic',now,now,'GB',85,'ASSERTS','ACTIVE','CLEAN-SOURCE','clean')
clean~setEventKey('EVENT-COMP'); clean~addConcept('SYNTH'); clean~setSourceAuthentication('VERIFIED','AUTH-CLEAN',.false,'HISTORY-CLEAN'); clean~seal
h=.ReputationEventHypothesis~new('H-COMP','SYNTH_EVENT'); h~addClaim(claim); h~addClaim(clean); h~seal
assessment=h~corroboration(.ReputationCorroborationPolicy~new(2,70,1,120,.true))
call assertEqual 2,assessment~claimCount,'both claims retained'
call assertEqual 1,assessment~eligibleAssertionClaimCount,'compromised family is discovery-only by default'
call assertEqual 1,assessment~discoveryOnlyClaimCount,'compromised claim remains visible'
call assertEqual 'CORROBORATING',assessment~status,'one clean family does not meet two-family threshold'
call assertEqual 'SOURCE_COMPROMISED',assessment~evidenceStatusForClaim('CLAIM-COMP')~reasonCode,'history drives explicit eligibility reason'

say 'PASS test_source_history_corroboration_bridge history=' || claim~sourceHistoryEvidenceId
exit 0

assertTrue: procedure
  use arg value,label
  if value \== .true then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'ReputationSourceAuthentication.cls'
::requires 'ReputationAcquisition.cls'
