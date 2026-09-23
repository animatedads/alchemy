parse arg polarOut spaceOut
if polarOut='' then polarOut='test_mlgraph_matplotlib_polar.png'
if spaceOut='' then spaceOut='test_mlgraph_matplotlib_spacetime.png'
f=0
r=.MLGraphRenderers~byName('MATPLOTLIB')
call check r~name='MATPLOTLIB','matplotlib renderer registered through optional package'

g=.MLGraph~polar('matplotlib polar provider')
pts=.array~new
do i=0 to 7
  v=.directory~new; v['angle']=i*45; v['radius']=(i//5)/4
  pts~append(.MLGraphPoint~new(v))
end
g~addSeries(.MLGraphSeries~new('trace',pts,'PRIMARY',.true))
g~addAnnotation(.MLGraphAnnotation~summary('published difference summary'))
g~render(r,polarOut)
call check stream(polarOut,'c','query size')>1000,'matplotlib polar image emitted with semantic annotation'

st=.MLGraph~spaceTime('time is a coordinate','time','radius','bend')
pts=.array~new
do i=0 to 9
  v=.directory~new; v['time']=i; v['radius']=(i//4)/3; v['bend']=((i+1)//5)-2
  pts~append(.MLGraphPoint~new(v))
end
st~addSeries(.MLGraphSeries~new('time trace',pts,'PRIMARY',.false))
call check r~supports(st),'matplotlib supports semantic 3D graph with TIME axis role'
st~render(r,spaceOut)
call check stream(spaceOut,'c','query size')>1000,'matplotlib 3D space/time image emitted'
if f=0 then do; say 'PASS MLGraph matplotlib 4 assertions'; exit 0; end
say 'FAIL MLGraph matplotlib failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphMatplotlib.cls'
