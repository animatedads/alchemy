/* Create reproducible small raw PTS fixture using ooRexx, no video/audio. */
parse arg mode
if mode=='' then mode='GOOD'
tab='09'x
samplePath='tests/stream_'||mode||'.samples.tsv'
runPath='tests/stream_'||mode||'.run.tsv'
source='synthetic.mp4'
call SysFileDelete samplePath
call SysFileDelete runPath
head=linein('tests/fixture.samples.tsv')
call stream 'tests/fixture.samples.tsv','C','CLOSE'
call lineout samplePath,head
ix=500;ms=0;count=0;cycle=0
lastPts=0;gapDone=.false
/* First timestamp 0, then irregular 60/120 ms steps; no ordinal-time fit. */
do forever
  count=count+1
  ix=ix+1
  pts=ms*90
  reported=ms
  observedSource=source
  if mode=='BAD_PTS' & count=5 then reported=ms+20
  if mode=='BAD_SOURCE' & count=5 then observedSource='wrong.mp4'
  if mode=='BAD_ORDER' & count=5 then pts=0
  epoch='E1';state='STABLE'
  if ms>=1500 then epoch='E2'
  if ms>=1900 & ms<=2100 then state='REACQUIRING'
  raw='FD_DOOR_MICRO_SAMPLE_V2'||tab||observedSource||tab||ix||tab||reported||tab||'00:00:00.000'||tab||pts||tab||epoch||tab||state||tab||'10'||tab||'20'||tab||'5'||tab||'12'||tab||'15'||tab||1||tab||0||tab||.3||tab||.4||tab||1||tab||2||tab||.1||tab||.12||tab||0||tab||0||tab||0||tab||0
  call lineout samplePath,raw
  lastPts=ms*90
  if ms>=3000 then leave
  cycle=cycle+1
  select
    when cycle//3=0 then dt=120
    otherwise dt=60
  end
  if ms>=2160 & \gapDone then do
    dt=360;gapDone=.true
  end
  if ms+dt>3000 then dt=3000-ms
  ms=ms+dt
end
call lineout samplePath
head=linein('tests/fixture.run.tsv')
call stream 'tests/fixture.run.tsv','C','CLOSE'
call lineout runPath,head
run='FD_DOOR_MICRO_RUN_V2'||tab||'0.1-dev2'||tab||'OK'||tab||'/private/synthetic.mp4'||tab||source||tab||'999'||tab||'999'||tab||count||tab||0||tab||2||tab||0||tab||0||tab||lastPts||tab||1||tab||90000||tab||ms||tab||'NO'||tab||'FDDMM2|STEP=1'
call lineout runPath,run
call lineout runPath
say 'GENERATED' mode 'SAMPLES='count 'LAST_MS='ms