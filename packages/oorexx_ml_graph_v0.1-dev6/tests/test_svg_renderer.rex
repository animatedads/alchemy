parse arg out
if out='' then out='test_mlgraph.svg'
f=0
g=.MLGraph~polar('circle with dots explains pattern identity')
p=.array~new
do i=0 to 7
  v=.directory~new; v['angle']=i*45; v['radius']=(i//5)/4
  p~append(.MLGraphPoint~new(v))
end
g~addSeries(.MLGraphSeries~new('technical trace',p,'PRIMARY',.true))
g~addAnnotation(.MLGraphAnnotation~summary('dominant TURN/VALUE & evidence'))
r=.MLGraphRenderers~byName('SVG')
call check r~supports(g),'SVG supports polar semantic graph'
g~render(r,out)
size=stream(out,'c','query size')
call check size>1000,'SVG output is non-empty'
s=.stream~new(out); s~open('read'); text=s~charin(1,size); s~close
call check text~pos('<svg')>0,'SVG document emitted'
call check text~pos('class="sample role-primary"')>0,'sample dots emitted as evidence'
call check text~pos('renderer does not normalize source data')>0,'renderer boundary is stated in output'
call check text~pos('graph-annotation summary')>0,'summary annotation is rendered'
call check text~pos('TURN/VALUE &amp; evidence')>0,'annotation text is XML escaped'
if f=0 then do; say 'PASS MLGraph SVG 7 assertions'; exit 0; end
say 'FAIL MLGraph SVG failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraph.cls'
