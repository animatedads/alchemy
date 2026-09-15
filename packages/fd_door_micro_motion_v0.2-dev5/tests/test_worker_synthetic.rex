parse arg root .
if root='' then root='.'
source=root||'/tests/synthetic_night_tiny.mp4'
prefix=root||'/qualification/synthetic'
stateDir=root||'/qualification/synthetic_state'
address system 'rm -rf '||stateDir||' '||prefix||'.*'
cfg=.FDDoorMicroMotionConfig~new
cfg~referenceMediaMs=0
cfg~bootstrapFrameXLo=0.25; cfg~bootstrapFrameXHi=0.38; cfg~fullSearchXLo=0.02; cfg~fullSearchXHi=0.66
cfg~maximumFrames=30
w=.FDDoorMicroMotionWorker~new(source,cfg,prefix,stateDir,'test:synthetic')
status=w~run
if status<>'OK' then do; say 'FAIL worker status='status; exit 1; end
runPath=prefix||'.run.tsv'
if stream(runPath,'C','QUERY EXISTS')=='' then do; say 'FAIL missing run'; exit 1; end
say 'PASS synthetic worker status='status
exit 0
::requires 'FDDoorMicroMotion.cls'
