now=.DateTime~new
set=.ReputationFeedPolicySet~new('AUDIT', -
  .ReputationLineagePolicy~new(78,2), -
  .ReputationCorroborationPolicy~new(2,70,1,180,.true), -
  .ReputationCorroborationEvidencePolicy~new(.false,.false,.false,.false), -
  .ReputationGeographicSaliencePolicy~new(2,5,3,10))~seal
bridge=.ReputationFeedInstitutionalPolicyBridge~new('REPUTATION-FEED-AUDIT')
release=bridge~newRelease('1.0',set,now-.TimeSpan~new(0,1,0,0,0),.nil,'AUTHOR','BOARD','')
catalog=.InstitutionalPolicyCatalog~new
call true catalog~publish(release)~ok,'publish audit policy'

verified=makeClaim('V','ASSERTION:V',91,'VERIFIED','CUSTOMER SECRET ONE')
unverified=makeClaim('U','ASSERTION:U',81,'UNVERIFIED','CUSTOMER SECRET TWO')
h=.ReputationEventHypothesis~new('H-AUDIT','AIRCRAFT_SAFETY_INCIDENT')
h~addClaim(verified); h~addClaim(unverified); h~seal
execution=bridge~operative(catalog,now); call true execution~ok,'resolve policy'
outcome=execution~value~corroborate(h)
call eq 'CORROBORATING',outcome~domainResult~status,'strict policy withholds unverified family'

trace=.ReputationFeedDecisionTrace~new('TRACE-001',outcome,h~hypothesisId,'')~seal
call eq 'TRACE-001',trace~traceId,'trace id'
call eq 'CORROBORATION',trace~operation,'operation'
call eq 'CORROBORATING',trace~outcomeStatus,'outcome status'
call eq 'REPUTATION-FEED-AUDIT',trace~policyId,'policy id'
call eq '1.0',trace~policyVersion,'policy version'
call eq set~semanticIdentity,trace~policySetIdentity,'policy set identity'
call eq 2,trace~claimCount,'claim count'
call eq 1,trace~eligibleClaimCount,'eligible claims'
call eq 1,trace~discoveryOnlyClaimCount,'discovery-only claims'
call eq 1,trace~eligibleIndependentFamilyCount,'eligible family count'
call eq 2,trace~requiredIndependentFamilies,'required families'
call eq 'CORROBORATION_CORROBORATING',trace~decisionCode,'derived decision code'
reasons=trace~reasonSummary
call true has(reasons,'ORIGIN_VERIFIED=1'),'verified reason summarized'
call true has(reasons,'ORIGIN_UNVERIFIED=1'),'unverified reason summarized'
call false trace~canonicalText~caselessPos('CUSTOMER SECRET ONE')>0,'raw claim title excluded from trace'
call false trace~canonicalText~caselessPos('CUSTOMER SECRET TWO')>0,'second raw claim title excluded from trace'
call true trace~sealed,'trace sealed'
adoption=.AlchemyAdoptionVerifier~verify(trace,'STANDARD'); call true adoption~ok,'decision trace Alchemy v0.8 adoption'

state=trace~queuePersistentState
restored=.ReputationFeedDecisionTrace~new('RESTORE')
restored~queueRestoreState(state)
call eq trace~canonicalText,restored~canonicalText,'direct persistence state replay canonical equality'
call eq 'reputation.feed.decision-trace/1',restored~queuePersistentType,'persistent type lock'

say 'PASS test_governed_decision_trace status='trace~outcomeStatus 'eligible='trace~eligibleClaimCount 'discovery='trace~discoveryOnlyClaimCount 'reasons='reasons~items
exit 0

makeClaim: procedure
  use arg id,root,confidence,authState,title
  c=.ReputationFeedClaim~new(id,'ART-'id,'PUB-'id,'AIRCRAFT_SAFETY_INCIDENT',title,.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-AUDIT')
  c~addSubject('MANUFACTURER','BOEING')
  c~addConcept('CABIN_OPENING')
  c~addAssertionOrigin(root,'SRC-'id,'PRIMARY_ASSERTION','EVID-'id,'audit root')
  c~setSourceAuthentication(authState,'AUTH-'id,.false,'HIST-'id)
  c~seal
  return c

has: procedure
  use arg items,wanted
  do item over items; if item == wanted then return .true; end
  return .false
true: procedure
  use arg value,label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
false: procedure
  use arg value,label
  if value then do; say 'FAIL:' label; exit 1; end
  return
eq: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'AlchemyAdoption.cls'
::requires 'ReputationDecisionAudit.cls'
::requires 'ReputationFeedInstitutionalPolicyBridge.cls'
