f=0
g=.MLGraph~cylindricalTime('one graph, several honest views')
ev=.directory~new; ev['source']='upstream-point'
v=.directory~new; v['x']=.25; v['y']=-.5; v['time']=.75
p=.MLGraphPoint~new(v,ev)
g~addSeries(.MLGraphSeries~new('trace',.array~of(p),'PRIMARY',.false,'series-evidence','VALUE'))

native=g~view
shape=g~view('SHAPE')
timeX=g~view('TIME_X')
timeY=g~view('TIME_Y')
call check native~kind='NATIVE' & native~nativeView,'native graph view is explicit'
call check shape~kind='AXIS_PAIR' & shape~axis1=1 & shape~axis2=2,'cylindrical SHAPE view selects existing x/y axes'
call check shape~aspect='EQUAL' & timeX~aspect='AUTO' & timeY~aspect='AUTO','shape view preserves geometry while time views use automatic aspect'
call check timeX~axis1=1 & timeX~axis2=3,'TIME_X view selects existing x/time axes'
call check timeY~axis1=2 & timeY~axis2=3,'TIME_Y view selects existing y/time axes'
call check g~axis(timeX~axis1)~role='CYLINDER_X' & g~axis(timeX~axis2)~role='TIME','TIME_X view exposes original semantic axis roles'
call check g~axis(timeY~axis1)~role='CYLINDER_Y' & g~axis(timeY~axis2)~role='TIME','TIME_Y view exposes original semantic axis roles'
call check shape~canonicalText='VIEW=SHAPE|kind=AXIS_PAIR|axis1=1|axis2=2|aspect=EQUAL','view canonical text is deterministic'
call check g~seriesAt(1)~point(1)~evidence==ev,'creating views does not replace point evidence'
call check g~seriesAt(1)~point(1)~value('time')=.75,'creating views does not change coordinates'
st=.MLGraph~spaceTime('generic 3D','time','radius','bend')
xz=st~view('XZ')
call check xz~axis1=1 & xz~axis2=3 & st~axis(xz~axis1)~role='TIME','generic 3D axis-pair views are available without cylinder semantics'

if f=0 then do; say 'PASS MLGraph views 11 assertions'; exit 0; end
say 'FAIL MLGraph views failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraph.cls'
