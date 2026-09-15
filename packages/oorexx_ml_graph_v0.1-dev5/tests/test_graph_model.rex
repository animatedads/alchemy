f=0
p=.MLGraph~polar('pattern')
call check p~coordinateSystem='POLAR','polar coordinate system'
call check p~dimensionCount=2,'polar dimension count'
call check p~axis(1)~role='ANGLE' & p~axis(2)~role='RADIUS','polar axis semantics'
call check p~grid~kind='POLAR' & p~grid~majorCount=4,'polar grid semantics'

st=.MLGraph~spaceTime('time is evidence','time','radius','bend')
call check st~dimensionCount=3,'space/time graph is genuinely 3D'
call check st~axis(1)~role='TIME','time is an explicit axis role, not implicit sample order'

v=.directory~new; v['time']=10; v['radius']=.4; v['bend']=-2
point=.MLGraphPoint~new(v,'evidence-1')
call check point~value('time')=10 & point~evidence='evidence-1','point retains coordinate and evidence'
copy=point~values; copy['time']=99
call check point~value('time')=10,'point values are protected from returned-map mutation'
series=.MLGraphSeries~new('trace',.array~of(point),'PRIMARY',.false,'series-evidence')
st~addSeries(series)
call check st~seriesCount=1 & st~seriesAt(1)~evidence='series-evidence','series is object evidence'

note=.MLGraphAnnotation~summary('published evidence only','difference-evidence')
st~addAnnotation(note)
call check st~annotationCount=1 & st~annotationAt(1)~kind='SUMMARY','graph owns semantic evidence annotations'
call check st~annotationAt(1)~evidence='difference-evidence' & \st~annotationAt(1)~locatable,'summary annotation retains evidence without inventing a location'
acopy=st~annotations; acopy~append(.MLGraphAnnotation~summary('mutate copy'))
call check st~annotationCount=1,'annotation list is protected from returned-array mutation'
call check st~canonicalText~pos('annotations=1')>0,'annotation count participates in graph canonical text'

names=.MLGraphRenderers~names
call check names~items>=1 & names[1]='SVG','reference renderer is registered'

if f=0 then do; say 'PASS MLGraph model 14 assertions'; exit 0; end
say 'FAIL MLGraph model failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraph.cls'
