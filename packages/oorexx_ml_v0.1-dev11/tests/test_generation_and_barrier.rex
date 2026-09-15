initial=.directory~new; initial['weight']=1
m=.MLDriveableObject~new('model-x','MODEL',initial)
registry=.MLLearnedGenerationRegistry~new
source=.MLSourceIdentity~new('MLCore','MAIN','3','dev1','SR-ABC','sha256:demo')
g1=registry~publish(m,'baseline',source)
c=.directory~new; c['weight']=2; m~mutate(c,'LEARN')
call eq 1,g1~state['weight'],'generation immutable after live mutation'
call eq 2,m~at('weight'),'live state advanced'
call eq 'SR-ABC',g1~sourceIdentity~revision,'source revision retained'

exp=.MLExperiment~new('barrier-demo')
exp~register('model',m)
cp0=exp~checkpoint('before-source-change','SOURCE')
barrier=.MLLearningBarrier~new('SRC-2','camera/source discontinuity',source,.MLSourceIdentity~new('MLCore','ALT','3','dev2'))
cpb=exp~barrier(barrier)
call true cpb~checkpointId\==cp0~checkpointId,'barrier creates explicit checkpoint'
say 'PASS test_generation_and_barrier'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
