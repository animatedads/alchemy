parse arg out
if out='' then out='test_mlgraph_cylinder.svg'
f=0
g=.MLGraph~cylindricalTime('cylindrical time evidence')
pts=.array~new
call RxFuncAdd 'RxCalcSin','rxmath','RxCalcSin'; call RxFuncAdd 'RxCalcCos','rxmath','RxCalcCos'
do i=0 to 11
  a=i*30; r=.35+.45*((i//4)/3); v=.directory~new
  v['x']=r*RxCalcCos(a,12,'D'); v['y']=r*RxCalcSin(a,12,'D'); v['time']=i/11
  pts~append(.MLGraphPoint~new(v,'event='||i))
end
g~addSeries(.MLGraphSeries~new('trajectory',pts,'PRIMARY',.false,'series-evidence'))
r=.MLGraphRenderers~byName('SVG')
call check r~supports(g),'SVG supports declared 3D Cartesian graph'
g~render(r,out)
size=stream(out,'c','query size')
call check size>1500,'3D SVG output is non-empty'
s=.stream~new(out); s~open('read'); text=s~charin(1,size); s~close
call check text~pos('3D coordinates are supplied evidence')>0,'renderer boundary is stated in 3D output'
call check text~pos('later')>0 & text~pos('earlier')>0,'declared cylindrical TIME guide is emitted'
call check text~pos('class="sample role-primary"')>0,'3D sample points are retained visibly'
if f=0 then do; say 'PASS MLGraph 3D SVG 5 assertions'; exit 0; end
say 'FAIL MLGraph 3D SVG failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraph.cls'
