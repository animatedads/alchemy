lib = .InteractionCaptureLibrary~new
call makeEvent lib,'g1','AGENT_UTTERANCE','CHAT','CHAT.AGENT_REPLY','case-sass'
style = .InteractionAssessmentFactory~style('style1','g1','style-llm','comm-style-v2',94)
style~addDimension('SASS',81)
style~addDimension('ABRUPTNESS',94)
style~addDimension('DISMISSIVENESS',88)
style~addDimension('WARMTH',7)
style~addDimension('CLOSURE_STRENGTH',96)
style~addDimension('RELATIONAL_REGISTER','INTERPERSONAL_CONFLICT')
style~seal
call assertTrue lib~attachAssessment(style)~ok, 'style assessment attached'

call makeEvent lib,'g2','SUBSCRIPTION_MANAGEMENT_OPENED','WEB_UI','UI.SUBSCRIPTION_MANAGE','case-sass'
call makeEvent lib,'g3','CANCELLATION_FLOW_ENTERED','BILLING','BILLING.CANCEL_BEGIN','case-sass'
call makeEvent lib,'g4','SUBSCRIPTION_CANCELLED','BILLING','BILLING.CANCEL_CONFIRMED','case-sass'
call makeEvent lib,'g5','CHAT_EXPORTED','CHAT','CHAT.EXPORT','case-sass'
call makeEvent lib,'g6','CHAT_DELETED','CHAT','CHAT.DELETE','case-sass'
call makeEvent lib,'g7','NEGATIVE_EXTERNAL_COMMUNICATION','EXTERNAL','SOCIAL.OBSERVATION','case-sass'

call assertTrue lib~linkEvents('s1','g1','g2','PRECEDES',100,'ASSOCIATED','SESSION_CORRELATOR')~ok, 'precedes'
call assertTrue lib~linkEvents('s2','g2','g3','STEP_OF',100,'NONE','BILLING')~ok, 'step 1'
call assertTrue lib~linkEvents('s3','g3','g4','STEP_OF',100,'NONE','BILLING')~ok, 'step 2'
call assertTrue lib~markCandidateTrigger('ct1','g1','g4',78,'EFFECT_ANALYSER')~ok, 'candidate trigger'
call assertTrue lib~linkEvents('s4','g4','g7','PRECEDES',100,'ASSOCIATED','SESSION_CORRELATOR')~ok, 'external complaint after exit'

links = lib~linksFrom('g1')
call assertEqual 2, links~items, 'agent utterance exposes multiple downstream links'
foundCandidate = .false
do l over links
  if l~linkKind = 'CANDIDATE_TRIGGER' then do
    foundCandidate = .true
    call assertEqual 'CANDIDATE_NOT_PROVEN', l~causalStatus, 'not promoted to causal fact'
  end
end
call assertTrue foundCandidate, 'candidate trigger present'
call assertEqual 7, lib~eventsForCorrelation('case-sass')~items, 'full correlated behavioural chain'
say 'PASS test_sass_commercial_chain'
exit 0
makeEvent: procedure
  use arg lib,id,kind,surface,point,corr
  e = .InteractionEvent~new(id,kind,.nil,surface,point,'OBSERVED')
  e~addCorrelation(corr)
  e~seal
  r = lib~captureEvent(e)
  if \r~ok then do; say 'FAIL: capture' id r~code; exit 1; end
  return
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'
