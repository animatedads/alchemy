f=0
base=.array~of(0,1,3,7,10,7,3,1)
scaled=.array~of(100,110,130,170,200,170,130,110)
policy=.MLPatternHashPolicy~new(36,48,1,4,10,.true,.false)
schema=.MLPatternHashSchema~new(policy,'GRAPH-ADAPTER-TEST')
h0=schema~encode(base); hs=schema~encode(scaled)
call check h0~key==hs~key,'fixture is affine-invariant in MLPatternHash'
g=.MLPatternGraphAdapter~overlay('pattern, not number',.array~of(hs,h0),.array~of('scaled/offset','base'),.array~of('EQUIVALENT','PRIMARY'))
call check g~seriesCount=2,'adapter creates semantic series'
call check g~seriesAt(1)~evidence==hs & g~seriesAt(2)~evidence==h0,'series retains the originating MLPatternHash as evidence'
call check g~seriesAt(1)~evidence~sourceMaximum=200 & g~seriesAt(2)~evidence~sourceMaximum=10,'absolute amplitude survives as evidence'
identical=.true
p1=g~seriesAt(1)~points; p2=g~seriesAt(2)~points
if p1~items<>p2~items then identical=.false
else do i=1 to p1~items
  if abs(p1[i]~value('radius')-p2[i]~value('radius'))>0.00000001 then identical=.false
  if p1[i]~value('angle')<>p2[i]~value('angle') then identical=.false
end
call check identical,'adapter exposes the same normalized geometry to display precision without renormalizing'
if f=0 then do; say 'PASS MLGraph pattern adapter 5 assertions'; exit 0; end
say 'FAIL MLGraph pattern adapter failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraph.cls'
::requires 'OorexxML.cls'
