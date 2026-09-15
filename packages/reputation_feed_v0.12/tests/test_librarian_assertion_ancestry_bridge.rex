now=.DateTime~new
source=.ReputationSourceIdentity~new('NEWS-X','NEWS','News X','GROUP-X','','GB','EDITORIAL_REPORTING','ENDPOINT-X'); source~seal
envelope=.ReputationRawEnvelope~new('ENV-X',source,now,now,'TEXT/HTML','https://example.test/x','EN','digest-x')
envelope~addSegment('HEADLINE','Manufacturer says event occurred')
envelope~addSegment('BODY','Article paraphrases the manufacturer statement.')
envelope~seal
adapter=.ReputationNewsPublicationAdapter~new
acquired=adapter~adapt(envelope)
call assertTrue acquired~accepted,'news acquisition succeeds'
handoff=acquired~librarianHandoff
finding=.ReputationLibrarianFinding~new('FIND-X',handoff~handoffId,'AIRCRAFT_SAFETY_INCIDENT','Manufacturer assertion',now,77,'ASSERTS')
finding~setEventKey('EVENT-X')
finding~addParagraphIndex(1)
finding~addConcept('CABIN_OPENING')
finding~addAssertionOrigin('BOEING-PR-X','BOEING','DERIVED_FROM','PARAGRAPH-LINEAGE-X','Librarian resolved quoted assertion ancestry')
finding~seal
claim=.ReputationLibrarianClaimBridge~new~claimFromFinding('CLAIM-X','PUB-FAM-X',handoff,finding)
call assertTrue claim~sealed,'bridge returns sealed claim'
call assertTrue claim~assertionAncestryResolved,'claim retains Librarian assertion ancestry'
call assertEqual 'BOEING-PR-X',claim~assertionOriginFamilyId,'assertion root copied from finding'
call assertEqual 1,claim~assertionOrigins~items,'ancestry link retained as rich object'
call assertTrue claim~assertionOrigins[1]~isA(.AlchemyObject),'ancestry link inherits Alchemy house base'
call assertEqual 'BOEING',claim~assertionOrigins[1]~sourceId,'primary assertion source retained'
call assertEqual 'DERIVED_FROM',claim~assertionOrigins[1]~relationship,'ancestry relationship retained'
call assertEqual 'ASSERTION:BOEING-PR-X',claim~corroborationFamilyId,'corroboration family resolves to assertion root'
call assertEqual 77,claim~confidence,'ancestry does not alter Librarian confidence'
call assertTrue pos('BOEING-PR-X',claim~canonicalText)>0,'canonical claim retains assertion ancestry evidence'

say 'PASS test_librarian_assertion_ancestry_bridge family='claim~corroborationFamilyId
exit 0
assertTrue: procedure
  use arg value,label
  if value \== .true then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
::requires 'ReputationAcquisition.cls'
