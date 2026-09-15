lib = .InteractionCaptureLibrary~new
agent = .InteractionReference~new('AGENT','support-bot','ORGANISATION','SUPPORT_AGENT','SYSTEM')
e = .InteractionEvent~new('reply-1','AGENT_UTTERANCE',agent,'CHAT','CHAT.AGENT_REPLY','OUTBOUND')
e~addCorrelation('commercial-session-1')
e~addContent(.InteractionContentElement~new('u1','UTTERANCE',"I'm done.",'PUBLIC','','RETAIN','AGENT_OUTPUT'))
e~seal
lib~captureEvent(e)
style = .InteractionAssessmentFactory~style('style-1','reply-1','communication-assessor','style-v1',94)
style~addDimension('SASS',81); style~addDimension('ABRUPTNESS',94); style~addDimension('DISMISSIVENESS',88); style~addDimension('CLOSURE_STRENGTH',96); style~seal
lib~attachAssessment(style)

c = .InteractionEvent~new('cancel-1','SUBSCRIPTION_CANCELLED',.nil,'BILLING','BILLING.CANCEL_CONFIRMED','OBSERVED')
c~addCorrelation('commercial-session-1'); c~seal; lib~captureEvent(c)
lib~markCandidateTrigger('candidate-1','reply-1','cancel-1',78,'effect-analyser')

say 'Event point:' lib~pointFor('reply-1')~pointId
say 'Style: sass=' style~dimensions['SASS'] 'abruptness=' style~dimensions['ABRUPTNESS'] 'dismissiveness=' style~dimensions['DISMISSIVENESS']
link = lib~linksFrom('reply-1')[1]
say 'Downstream:' link~linkKind link~toEventId 'confidence='link~confidence 'causal='link~causalStatus
say 'Interpretation: candidate contributor, not a stored causal fact.'
exit 0
::requires 'InteractionEvent.cls'
