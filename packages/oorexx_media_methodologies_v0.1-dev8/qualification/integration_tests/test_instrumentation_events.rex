#!/usr/bin/env rexx
adapter=.MediaMethodologyInstrumentation~new(8)
subject='media-experiment:EXP-1:LINEAGE-1:WORK-1'
related=.Array~of('sha256:source')
a=adapter~started('m1',subject,'AUDIO.RECON.MULTIPATH_VIRTUAL_MIC','audio-v9.candidate18.echo-reconstruct-nonamp/0.1','2026-10-10T14:00:00Z','EXP-1','WORK-1',related)
b=adapter~completed('m2',subject,'AUDIO.RECON.MULTIPATH_VIRTUAL_MIC','audio-v9.candidate18.echo-reconstruct-nonamp/0.1','file:virtual.f32','2026-10-10T14:00:01Z','EXP-1','WORK-1',related)
call assertEq 'MEDIA_METHODOLOGY_EXECUTION',a['authority'],'execution event authority'
call assertTrue \a['derived'],'source execution event is not collector-derived'
call assertTrue \b['evidence']['observation_promotion'],'instrumentation cannot promote candidate to observation'
collector=.InstrumentationCollector~new(16)
do event over adapter~events
  /* storeEvent is intentionally exercised directly here; the collector owns replay fencing. */
  collector~storeEvent(event)
end
call assertEq 2,collector~eventsHistory~items,'events retained'
call assertTrue \collector~storeEvent(a),'replay is idempotent by event identity'
call assertEq 2,collector~eventsHistory~items,'replay did not duplicate history'
say 'PASS media methodology execution events through Instrumentation Mesh dev7'
exit 0
assertTrue: procedure
  use arg value,label
  if value then return
  say 'FAIL' label
  exit 1
assertEq: procedure
  use arg expected,actual,label
  if expected==actual then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1
::requires 'InstrumentationMesh.cls'
::requires 'MediaMethodologyInstrumentation.cls'
