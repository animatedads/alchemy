lib = .InteractionCaptureLibrary~new
who = .InteractionReference~new('CUSTOMER','Jane Example','CUSTOMER_SPECIFIC','CUSTOMER','CUSTOMER_INPUT')
e = .InteractionEvent~new('p-demo','CUSTOMER_UTTERANCE',who,'CHAT','CHAT.POST_TURN','INBOUND')
e~addContent(.InteractionContentElement~new('raw','UTTERANCE','My ABC123 router has failed four times and I am furious','CUSTOMER_SPECIFIC','customer reported repeated supplied-equipment failure with strong frustration','ABSTRACT_ONLY','CUSTOMER_INPUT'))
e~addContent(.InteractionContentElement~new('semantic','FAILURE_PATTERN','REPEATED_PRODUCT_FAILURE','DERIVED_NONCUSTOMER','','RETAIN','MODEL_DERIVED'))
e~seal; lib~captureEvent(e)
p = lib~projectEvent('p-demo')~value
say 'Projected actor:' p~actorRef~value '('p~actorRef~projectionKind')'
do x over p~content
  say x~semanticType || ':' x~value '[' || x~projectionKind || ']'
end
exit 0
::requires 'InteractionEvent.cls'
