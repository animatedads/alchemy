now = .DateTime~new
source = .ReputationSourceIdentity~new('NEWS-A','NEWS','News A','GROUP-A','OWNER-A','GB','EDITORIAL_REPORTING','news-a-feed')
source~seal
envelope = .ReputationRawEnvelope~new('ENV-CLAIM-A',source,now,now,'TEXT/PLAIN','https://news.example/a','EN','1111111111111111111111111111111111111111111111111111111111111111')
envelope~addField('TITLE','Synthetic event report')
envelope~addField('OBSERVED_GEOGRAPHY','GB')
envelope~addSegment('HEADLINE','Synthetic event report')
envelope~addSegment('BODY','A synthetic event occurred for deterministic testing.')
envelope~seal
adapter = .ReputationNewsPublicationAdapter~new
acquired = adapter~adapt(envelope)
call assertTrue acquired~accepted,'news document acquired'
handoff = acquired~librarianHandoff
finding = .ReputationLibrarianFinding~new('FIND-A',handoff~handoffId,'SYNTH_EVENT','Synthetic event',now,73,'ASSERTS')
finding~setEventKey('EVENT-A')
finding~addParagraphIndex(1)
finding~addConcept('SYNTHETIC')
finding~addAffectedGeography('GB')
finding~seal

verified = .ReputationSourceAuthenticationResult~new('AUTH-VERIFIED','NEWS-A','BIND-A','PROOF-A','ED25519','KEY-A',now,.true,'VERIFIED','ORIGIN_VERIFIED','origin verified')
history = .ReputationSourceHistoryView~new('NEWS-A',now,1,'VERIFIED','BIND-A','KEY-A','news-a-feed',.false,1,0,0,0,.array~of('AUTHENTICATION'))
packet = .ReputationSourceEvidencePacket~new('PACKET-A',envelope,verified,history)
packet~seal
bridge = .ReputationLibrarianClaimBridge~new
claim = bridge~claimFromFinding('CLAIM-A','FAMILY-A',handoff,finding,'ACTIVE',packet)
call assertEqual 73,claim~confidence,'origin verification does not inflate Librarian confidence'
call assertEqual 'VERIFIED',claim~sourceAuthenticationState,'verified source state retained on claim'
call assertEqual 'AUTH-VERIFIED',claim~sourceAuthenticationEvidenceId,'authentication evidence identity retained'

failed = .ReputationSourceAuthenticationResult~new('AUTH-FAILED','NEWS-A','BIND-A','PROOF-B','ED25519','KEY-A',now,.false,'FAILED','PROOF_INVALID','origin proof failed')
failedPacket = .ReputationSourceEvidencePacket~new('PACKET-B',envelope,failed,.nil)
failedPacket~seal
claimFailed = bridge~claimFromFinding('CLAIM-B','FAMILY-B',handoff,finding,'ACTIVE',failedPacket)
call assertEqual 73,claimFailed~confidence,'authentication failure does not silently rewrite content confidence'
call assertEqual 'FAILED',claimFailed~sourceAuthenticationState,'failed origin state retained explicitly'
call assertTrue pos('SOURCE_AUTH_STATE',claimFailed~canonicalText) > 0,'canonical claim includes source authentication evidence'

say 'PASS test_source_auth_claim_bridge confidence=' || claim~confidence
exit 0

assertTrue: procedure
  use arg value,label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'ReputationSourceAuthentication.cls'
::requires 'ReputationAcquisition.cls'
