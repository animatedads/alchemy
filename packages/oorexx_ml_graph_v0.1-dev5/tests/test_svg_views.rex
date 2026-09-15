parse arg shapeOut timeXOut timeYOut cartOut
if shapeOut='' then shapeOut='test_mlgraph_view_shape.svg'
if timeXOut='' then timeXOut='test_mlgraph_view_timex.svg'
if timeYOut='' then timeYOut='test_mlgraph_view_timey.svg'
if cartOut='' then cartOut='test_mlgraph_cartesian2.svg'
f=0
g=.MLGraph~cylindricalTime('projection is presentation')
pts=.array~new
call RxFuncAdd 'RxCalcSin','rxmath','RxCalcSin'; call RxFuncAdd 'RxCalcCos','rxmath','RxCalcCos'
do i=0 to 8
  a=i*40; rr=.3+.05*i; v=.directory~new
  v['x']=rr*RxCalcCos(a,12,'D'); v['y']=rr*RxCalcSin(a,12,'D'); v['time']=i/8
  pts~append(.MLGraphPoint~new(v,'event='||i))
end
g~addSeries(.MLGraphSeries~new('trajectory',pts,'PRIMARY',.false,'series-evidence','VALUE'))
r=.MLGraphRenderers~byName('SVG')
shape=g~view('SHAPE'); timeX=g~view('TIME_X'); timeY=g~view('TIME_Y')
call check r~supports(g,shape) & r~supports(g,timeX) & r~supports(g,timeY),'SVG supports named axis-pair views of one 3D graph'
g~render(r,shapeOut,shape); g~render(r,timeXOut,timeX); g~render(r,timeYOut,timeY)
call check stream(shapeOut,'c','query size')>1200 & stream(timeXOut,'c','query size')>1200 & stream(timeYOut,'c','query size')>1200,'all projected SVGs are emitted'
shapeText=slurp(shapeOut); txText=slurp(timeXOut); tyText=slurp(timeYOut)
call check shapeText~pos('data-graph-view="SHAPE"')>0 & shapeText~pos('[CYLINDER_X]')>0 & shapeText~pos('[CYLINDER_Y]')>0,'SHAPE SVG declares cylinder x/y projection'
call check shapeText~pos('x="150" y="70" width="560" height="560"')>0,'SHAPE SVG uses an equal-aspect presentation box'
call check txText~pos('data-graph-view="TIME_X"')>0 & txText~pos('[CYLINDER_X]')>0 & txText~pos('[TIME]')>0,'TIME_X SVG declares x/time projection'
call check tyText~pos('data-graph-view="TIME_Y"')>0 & tyText~pos('[CYLINDER_Y]')>0 & tyText~pos('[TIME]')>0,'TIME_Y SVG declares y/time projection'
call check txText~pos('projection selects existing axes only; semantic coordinates are unchanged')>0,'projected output states presentation boundary'
call check g~seriesAt(1)~point(9)~value('time')=1,'projection rendering leaves original graph coordinate untouched'

c=.MLGraph~cartesian2('ordinary cartesian','dose','response','INPUT','OUTPUT')
a=.array~new
do i=0 to 3; v=.directory~new; v['dose']=i; v['response']=i*i; a~append(.MLGraphPoint~new(v)); end
c~addSeries(.MLGraphSeries~new('response',a))
call check r~supports(c),'SVG now supports native 2D Cartesian graphs'
c~render(r,cartOut)
call check stream(cartOut,'c','query size')>900 & slurp(cartOut)~pos('[INPUT]')>0 & slurp(cartOut)~pos('[OUTPUT]')>0,'native 2D Cartesian SVG is emitted using original axes'

if f=0 then do; say 'PASS MLGraph SVG views 10 assertions'; exit 0; end
say 'FAIL MLGraph SVG views failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
slurp: procedure
  parse arg path
  size=stream(path,'c','query size'); s=.stream~new(path); s~open('read'); text=s~charin(1,size); s~close
  return text
::requires 'MLGraph.cls'
