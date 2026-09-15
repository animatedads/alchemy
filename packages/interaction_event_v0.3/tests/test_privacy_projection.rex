lib = .InteractionCaptureLibrary~new
customer = .InteractionReference~new('CUSTOMER','Jane Example','CUSTOMER_SPECIFIC','CUSTOMER','CUSTOMER_INPUT')
e = .InteractionEvent~new('p1','CUSTOMER_UTTERANCE',customer,'CHAT','CHAT.POST_TURN','INBOUND')
e~addContent(.InteractionContentElement~new('name','CUSTOMER_NAME','Jane Example','CUSTOMER_SPECIFIC','','DROP','CUSTOMER_INPUT'))
e~addContent(.InteractionContentElement~new('addr','CUSTOMER_LOCATION','12 Somewhere Road','CUSTOMER_SPECIFIC','','DROP','CUSTOMER_INPUT'))
e~addContent(.InteractionContentElement~new('serial','PRODUCT_SERIAL','ABC123','CUSTOMER_SPECIFIC','SUPPLIED_NETWORK_EQUIPMENT','ABSTRACT_ONLY','CUSTOMER_INPUT'))
e~addContent(.InteractionContentElement~new('failure','FAILURE_PATTERN','failed four times this month','CUSTOMER_SPECIFIC','REPEATED_PRODUCT_FAILURE_WITHIN_RECENT_PERIOD','ABSTRACT_ONLY','CUSTOMER_INPUT'))
e~addContent(.InteractionContentElement~new('unknown','FREE_TEXT','possible secret detail','UNKNOWN','tempting abstraction','RETAIN','MODEL_DERIVED'))
e~addContent(.InteractionContentElement~new('class','SERVICE_OBJECT','WIFI_ROUTER','DERIVED_NONCUSTOMER','','RETAIN','MODEL_DERIVED'))
e~seal
call assertTrue lib~captureEvent(e)~ok, 'captured'

r = lib~projectEvent('p1')
call assertTrue r~ok, 'projected'
p = r~value
call assertTrue p~actorRef \== .nil, 'actor abstracted rather than raw'
call assertEqual 'CUSTOMER', p~actorRef~value, 'actor abstraction retained'
call assertEqual 'ABSTRACTED', p~actorRef~projectionKind, 'actor projection kind'
call assertEqual 3, p~content~items, 'only safe/abstracted semantic residue retained'
text = ''
do x over p~content; text ||= '|' || x~value; end
call assertTrue text~pos('Jane Example') = 0, 'name removed'
call assertTrue text~pos('12 Somewhere Road') = 0, 'address removed'
call assertTrue text~pos('ABC123') = 0, 'serial removed'
call assertTrue text~pos('possible secret detail') = 0, 'unknown raw removed'
call assertTrue text~pos('tempting abstraction') = 0, 'unknown abstraction fails closed'
call assertTrue text~pos('SUPPLIED_NETWORK_EQUIPMENT') > 0, 'equipment abstraction retained'
call assertTrue text~pos('REPEATED_PRODUCT_FAILURE_WITHIN_RECENT_PERIOD') > 0, 'failure abstraction retained'
call assertTrue text~pos('WIFI_ROUTER') > 0, 'noncustomer semantic class retained'
say 'PASS test_privacy_projection'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'
