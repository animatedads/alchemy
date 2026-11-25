service=.LogService~new('mi-test')
target=.LogMemoryTarget~new('local',.Log~INTERNAL)
service~addTarget(target)
service~addRule(.LogRule~new('mi','mi','TestEmitter','EVENT',.Log~INTERNAL,.Log~INTERNAL,.Log~INFO,.nil,.array~of('local')))
logger=service~loggerFor(.TestEmitter~new,'EVENT',.array~new,.Log~INTERNAL)
b=.FixtureBackend~new('/bin/sleep'); r=.FixtureRegistrar~new
l=.MiLauncher~new('cats2',b,r,logger)
a=.MiLaunchSpec~new('mi1','cats2','1','mi.one','/image/one')
c=.MiLaunchSpec~new('mi2','cats2','1','mi.two','/image/two')
d=.MiLaunchSpec~new('mi3','cats2','1','mi.three','/image/three')
call check l~start(.MiLaunchSpec~new('mi1','other','1','mi.one','/image/one'))=='WRONG_OWNER','wrong owner refused'
call check l~start(a)=='STARTING','actual first child launched'
call check l~start(a)=='ALREADY_PRESENT','duplicate refused'
call check l~start(.MiLaunchSpec~new('mi3','cats2','1','mi.one','/image/three'))=='RESOURCE_CONFLICT','service collision refused'
call check l~start(.MiLaunchSpec~new('mi3','cats2','1','mi.three','/image/one'))=='RESOURCE_CONFLICT','root collision refused'
call check l~start(c)=='STARTING','actual second child launched'
call check l~count=2,'two children tracked'
call check l~exitSources~items=2,'two native exit sources'
mux=.POSIXProvider~new~openEventMux['MUX']
do row over l~exitSources; call check mux~register(row['HANDLE'])['OK'],'register MI exit with native mux'; end
call check l~start(d)=='CAPACITY','capacity bounded'
call check l~poll('mi1')=='STARTING','process alive is not registration'
r~mode='STALE'
call check l~poll('mi1')=='STARTING','stale incarnation refused'
r~mode='WRONG_SERVICE'
call check l~poll('mi1')=='STARTING','wrong service refused'
r~mode='UNVERIFIED'
call check l~poll('mi1')=='STARTING','unverified registration refused'
r~mode='VALID'
call check l~poll('mi1')=='REGISTERED','fixture registration first'
call check l~poll('mi2')=='REGISTERED','fixture registration second'
r~mode='MISSING'
call check l~poll('mi1')=='STARTING','registration withdrawal observed'
call check l~stop('mi1','old')=='STALE_INCARNATION','stale stop refused'
call check l~stop('mi1','1')=='EXITED','pidfd stop and reap first'
call check l~count=1,'first slot released'
call check mux~wait(0)['EVENTS']~items>=1,'mux observes closed MI source'
call check l~start(a)=='INCARNATION_REUSED','reuse incarnation refused'
call check l~stop('mi2','1')=='EXITED','pidfd stop and reap second'
call check l~count=0,'second slot released'
mux~close
call check target~count>=10,'structured logging delivered'
call check target~events[1]~payload['KIND']=='MI_START_REQUEST','request logged before launch'
b~duration='0.2'
call check l~start(d)=='STARTING','short-lived child started'
row=l~exitSources[1]; call check row['HANDLE']~waitExit(5000)['EXITED'],'actual spontaneous exit ready'
call check l~poll('mi3')=='EXITED','spontaneous exit reaped'
call check l~count=0,'spontaneous exit releases slot'
b~duration='30'
e=.MiLaunchSpec~new('mi1','cats2','2','mi.one','/image/one2')
call check l~start(e)=='STARTING','new incarnation permitted'
service~disable('test loss')
r~mode='VALID'
call check l~poll('mi1')=='QUARANTINED','registration logging failure quarantines'
call check l~stop('mi1','2')=='EXITED','safety stop after logging failure'
call check l~start(d)=='LOG_UNAVAILABLE','logging disabled prevents new launch'
call check l~count=0,'no child after refused launch'
say 'MI SUITE PASSED'
exit 0
check: procedure
 use arg ok,label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label
 return
::requires 'MiLauncher.cls'
::requires 'POSIXProvider.cls'
::class TestEmitter
::class FixtureBackend subclass MiChildBackend
::attribute duration
::method init
 use strict arg helper
 self~init:super(helper)
 self~duration='30'
::method argv
 use strict arg spec
 return .array~of('/bin/sleep',self~duration)
::class FixtureRegistrar
::attribute mode
::method init
 self~mode='MISSING'
::method observe
 use strict arg id,owner,incarnation,service,identity
 if self~mode=='MISSING' then return .nil
 p=.Directory~new; p['MI']=id; p['MU']=owner; p['INCARNATION']=incarnation; p['SERVICE']=service; p['PROCESS_IDENTITY']=identity; p['VERIFIED']=.true
 select
 when self~mode=='STALE' then p['INCARNATION']='0'
 when self~mode=='WRONG_SERVICE' then p['SERVICE']='wrong'
 when self~mode=='UNVERIFIED' then p['VERIFIED']=.false
 otherwise nop
 end
 return p
