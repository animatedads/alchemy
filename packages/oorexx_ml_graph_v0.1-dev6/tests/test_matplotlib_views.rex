parse arg shapeOut timeXOut timeYOut
if shapeOut='' then shapeOut='test_mlgraph_matplotlib_view_shape.png'
if timeXOut='' then timeXOut='test_mlgraph_matplotlib_view_timex.png'
if timeYOut='' then timeYOut='test_mlgraph_matplotlib_view_timey.png'
f=0
g=.MLGraph~cylindricalTime('matplotlib projected views')
pts=.array~new
call RxFuncAdd 'RxCalcSin','rxmath','RxCalcSin'; call RxFuncAdd 'RxCalcCos','rxmath','RxCalcCos'
do i=0 to 10
  a=i*32; rr=.25+.04*i; v=.directory~new
  v['x']=rr*RxCalcCos(a,12,'D'); v['y']=rr*RxCalcSin(a,12,'D'); v['time']=i/10
  pts~append(.MLGraphPoint~new(v,'event='||i))
end
g~addSeries(.MLGraphSeries~new('trajectory',pts,'PRIMARY',.false,'series-evidence','VALUE'))
r=.MLGraphRenderers~byName('MATPLOTLIB')
shape=g~view('SHAPE'); tx=g~view('TIME_X'); ty=g~view('TIME_Y')
call check r~supports(g,shape) & r~supports(g,tx) & r~supports(g,ty),'matplotlib supports named axis-pair views'
g~render(r,shapeOut,shape); g~render(r,timeXOut,tx); g~render(r,timeYOut,ty)
call check stream(shapeOut,'c','query size')>2000,'matplotlib SHAPE projection emitted'
call check stream(timeXOut,'c','query size')>2000,'matplotlib TIME_X projection emitted'
call check stream(timeYOut,'c','query size')>2000,'matplotlib TIME_Y projection emitted'
call check g~seriesAt(1)~point(11)~evidence='event=10','matplotlib projections preserve source evidence'
if f=0 then do; say 'PASS MLGraph matplotlib views 5 assertions'; exit 0; end
say 'FAIL MLGraph matplotlib views failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphMatplotlib.cls'
