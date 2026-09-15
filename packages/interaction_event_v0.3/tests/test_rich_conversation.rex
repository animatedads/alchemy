lib = .InteractionCaptureLibrary~new
customer = .InteractionReference~new('CUSTOMER', 'customer-42', 'CUSTOMER_PSEUDONYMOUS', 'CUSTOMER', 'SYSTEM')
router = .InteractionReference~new('PRODUCT_CLASS', 'wifi-router', 'ORGANISATION', 'NETWORK_EQUIPMENT', 'SYSTEM')

c = .InteractionEvent~new('e1', 'CUSTOMER_UTTERANCE', customer, 'CHAT', 'CHAT.POST_TURN', 'INBOUND', .nil, .nil, router)
c~addCorrelation('case-7')
c~addTag('COMPLAINT')
c~addContent(.InteractionContentElement~new('c1','UTTERANCE','Your bloody wifi router keeps breaking','CUSTOMER_SPECIFIC','reported repeated network-equipment failure using strongly frustrated language','ABSTRACT_ONLY','CUSTOMER_INPUT','turn-2','0:44',100))
c~addContent(.InteractionContentElement~new('c2','SERVICE_PROPOSITION','REPEATED_FAILURE','DERIVED_NONCUSTOMER','','RETAIN','MODEL_DERIVED','turn-2','',94))
c~seal
call assertTrue lib~captureEvent(c)~ok, 'customer event captured'

sent = .InteractionAssessmentFactory~sentiment('a1','e1','FRUSTRATED','sentiment-llm','sent-v3',91)
sent~addDimension('INTENSITY', 82)
sent~addDimension('TARGET', 'SERVICE_OR_PRODUCT')
sent~addEvidenceRef('c1')
sent~seal
call assertTrue lib~attachAssessment(sent)~ok, 'sentiment attached'

a = .InteractionEvent~new('e2','AGENT_UTTERANCE',.InteractionReference~new('AGENT','support-bot','ORGANISATION','SUPPORT_AGENT','SYSTEM'),'CHAT','CHAT.AGENT_REPLY','OUTBOUND')
a~addCorrelation('case-7')
a~addTag('ACKNOWLEDGEMENT')
a~addTag('OFFER_ASSISTANCE')
a~addContent(.InteractionContentElement~new('a2c','UTTERANCE','Sure, let me help you with that ...','PUBLIC','','RETAIN','AGENT_OUTPUT','turn-3','',100))
a~seal
call assertTrue lib~captureEvent(a)~ok, 'agent event captured'
call assertTrue lib~linkEvents('l1','e2','e1','RESPONDS_TO',100,'NONE','CHAT_GATEWAY')~ok, 'response link'

call assertEqual 2, lib~eventsForCorrelation('case-7')~items, 'correlated timeline'
call assertEqual 1, lib~assessmentsFor('e1')~items, 'one assessment'
call assertEqual 'FRUSTRATED', lib~assessmentsFor('e1')[1]~value, 'assessment is retained as assessment'
say 'PASS test_rich_conversation'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'
