/* v0.2-dev7 multi-timescale visual door model qualification. */
parse arg root .
if root='' then root='.'

m=.FDTemporalDoorModel~new(0.05,1.0,0.35,4)
ignore=m~seed(10.0)

/* Slow quiet drift is baseline, not an event. */
do i=1 to 12
  g=10.0+(i*0.015)
  r=m~observe(g,.true,0.35)
  if r['CANDIDATE'] then call fail 'quiet drift became sustained evidence i='||i||' def='||r['DEFLECTION']
end
if abs(m~baseline-10.0)>0.20 then call fail 'quiet baseline did not follow bounded drift baseline='||m~baseline

/* A displacement that arrives through sub-threshold per-frame steps must be
   recoverable as sustained geometry evidence. */
candidate=.false
values=.array~of(10.30,10.48,10.62,10.74,10.82,10.84,10.86)
do g over values
  r=m~observe(g,.false,0.35)
  if r['CANDIDATE'] then candidate=.true
end
if \candidate then call fail 'sustained deflection not detected final='||r['DEFLECTION']||' count='||r['SUSTAINED_COUNT']
if abs(r['DEFLECTION'])<0.55 then call fail 'sustained deflection magnitude unexpectedly small '||r['DEFLECTION']

/* Return towards baseline clears sustained state. */
do g over .array~of(10.30,10.15,10.08,10.04)
  r=m~observe(g,.true,0.35)
end
if r['CANDIDATE'] then call fail 'candidate did not clear on return'

/* Door gap is relative geometry: common camera translation cancels, while a
   door-only displacement survives. */
cfg=.FDDoorMicroMotionConfig~nightF11
geom=.FDNightDoorGeometryModel~new(cfg)
a=makeGeometry(100.0,90.0)
b=makeGeometry(102.0,92.0)
c=makeGeometry(102.0,92.60)
ga=geom~doorGapState(a); gb=geom~doorGapState(b); gc=geom~doorGapState(c)
if ga['VALID_PROBES']<>3 | gb['VALID_PROBES']<>3 | gc['VALID_PROBES']<>3 then call fail 'gap probe count'
if abs(ga['GAP']-gb['GAP'])>0.001 then call fail 'common translation leaked into relative gap a='||ga['GAP']||' b='||gb['GAP']
if abs((gc['GAP']-gb['GAP'])-0.60)>0.001 then call fail 'door-only relative displacement missing delta='||(gc['GAP']-gb['GAP'])

say 'PASS temporal deflection baseline='||format(m~baseline,,4)||' final_deflection='||format(r['DEFLECTION'],,4)||' relative_delta='||format(gc['GAP']-gb['GAP'],,3)
exit 0

makeGeometry: procedure
  use arg frame,door
  d=.directory~new
  d['PANEL_X']=70; d['LOCATOR_SCORE']=20
  d['FRAME_UP']=.FDEdgeMeasurement~new(frame,10,10,.true)
  d['FRAME_LO']=.FDEdgeMeasurement~new(frame+0.10,10,10,.true)
  d['FRAME_BOTTOM']=.FDEdgeMeasurement~new(frame-0.10,10,10,.true)
  d['DOOR_UP']=.FDEdgeMeasurement~new(door,10,-10,.true)
  d['DOOR_LO']=.FDEdgeMeasurement~new(door+0.10,10,-10,.true)
  d['DOOR_BOTTOM']=.FDEdgeMeasurement~new(door-0.10,10,-10,.true)
  d['FLOOR_L']=.FDEdgeMeasurement~new(300,10,10,.true)
  d['FLOOR_R']=.FDEdgeMeasurement~new(300,10,10,.true)
  return d

fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
