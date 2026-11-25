/* Architecture: Tom Dyer. Coding: ChatGPT. */
numeric digits 25
scope=.Log~internalScope('APP-TEST'); svc=.LogService~new('generic'); handler=.LogOperationalHandler~new
reg=.LogSubscriptions~new(svc,scope,5,handler)
a=reg~register('orders','g','OrderProducer','COMMIT',.Array~of('COMMITTED'),'CRITICAL',2)
b=reg~register('detail','d','OrderProducer','COMMIT',.Array~of('COMMITTED'),'DIAGNOSTIC',2)
other=reg~register('stock','s','StockProducer','UPDATE',.Array~of('CHANGED'),'OPERATIONS',1)
p=.OrderProducer~new; reg~bind(svc,scope,p)
q=.StockProducer~new; reg~bind(svc,scope,q)
call check reg~publish(q,'UPDATE','CHANGED','stock') & other~pending=1 & a~pending=0,'generic second producer class independently routed'
call check reg~wants('OrderProducer','COMMIT','COMMITTED'),'generic class and method registration'
call check reg~publish(p,'COMMIT','COMMITTED','order 1'),'generic string payload retained'
obj=.OrderValue~new
call check reg~publish(p,'COMMIT','COMMITTED',obj),'generic arbitrary object payload'
call check a~read['EVENTS'][2]~payload==obj,'generic original object identity'
call check \reg~publish(p,'COMMIT','COMMITTED','overflow'),'generic critical overflow refuses even with optional mirror'
call check a~status['LOST']=1 & a~status['QUARANTINED'],'generic critical loss accounted'
call check has(handler,'LOGGING_LOSS'),'generic out-of-band operational handler receives loss'
call check badRecovery(reg,.Object~new),'generic unregistered recovery authority refused'
x=a~read; a~ack('g',x['NEXT'])
call check badLoss(reg,handler),'generic stale recovery loss count refused'
reg~rearm(handler,'orders',1,'reconciled by operator')
call check \a~status['QUARANTINED'] & a~status['LOST']=1 & a~status['RECOVERED_LOSS']=1,'generic recovery preserves historical gap'
call check has(handler,'LOGGING_REARM'),'generic recovery recorded out of band'
call check reg~publish(p,'COMMIT','COMMITTED','after recovery'),'generic new critical delivery allowed after rearm'
svc~disableRule(a~ruleId,'test','operator'); reg~pollState
call check has(handler,'LOGGING_LANE_DOWN') & a~status['QUARANTINED'],'generic idle disabled rule detected by explicit health check'
call check \reg~publish(p,'COMMIT','COMMITTED','disabled'),'generic disabled required rule cannot be masked'
svc~enableRule(a~ruleId,'test','operator')
call check \reg~publish(p,'COMMIT','COMMITTED','still quarantined'),'generic ordinary enable does not rearm'
svc~disableTarget(b~name); call check has(handler,'LOGGING_LANE_DOWN'),'generic target disable independent event'
say 'GENERIC SUBSCRIPTIONS SUITE PASSED'; exit 0
check:
 use arg ok,label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label; return
::routine has
 use strict arg h,k
 do e over h~events; if e['KIND']==k then return .true; end
 return .false
::routine badRecovery
 use strict arg r,h
 signal on syntax name refused
 r~rearm(h,'orders',1,'invalid'); return .false
refused: return .true
::routine badLoss
 use strict arg r,h
 signal on syntax name refused
 r~rearm(h,'orders',0,'invalid'); return .false
refused: return .true
::class OrderProducer
::class StockProducer
::class OrderValue
::requires 'LoggingSubscriptions.cls'
