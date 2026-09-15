f=0
names=.array~of('PRICE','RELATIVE','FX','VOL'); weights=.array~of(1,4,4,2)
tA=.array~of(0,1,2,4,5,7,8,10,13,15)
priceA=.array~of(100,102,105,104,108,111,110,114,117,121)
relA=.array~of(0,.3,.8,.4,1.1,1.7,1.4,2.1,2.5,3.0)
fxA=.array~of(0,-.2,-.4,-.6,-.5,-.2,.1,.3,.2,0)
volA=.array~of(18,18,19,20,19,18,19,18,17,18)
A=.MLTemporalPatternSeries~new(tA,names,.array~of(priceA,relA,fxA,volA),weights,'A')
priceB=.array~of(100,102.1,105.1,104.2,108.2,111.2,110.1,114.1,117.1,121.1)
relB=.array~of(0,-.3,-.8,-1.0,-.7,-.2,.2,.7,1.0,1.2)
fxB=.array~of(0,.4,.9,1.2,1.6,2.0,2.4,2.8,3.0,3.4)
volB=.array~of(18,20,23,26,25,28,30,32,31,33)
B=.MLTemporalPatternSeries~new(tA,names,.array~of(priceB,relB,fxB,volB),weights,'B')
tC=.array~new; do x over tA; tC~append(100+2*x); end
priceC=.array~new; do x over priceA; priceC~append(250+2.5*(x-100)); end
relC=.array~new; do x over relA; relC~append(50+7*x); end
fxC=.array~new; do x over fxA; fxC~append(-20+3*x); end
volC=.array~new; do x over volA; volC~append(200+4*(x-17)); end
C=.MLTemporalPatternSeries~new(tC,names,.array~of(priceC,relC,fxC,volC),weights,'C')
policy=.MLTemporalPatternPolicy~new(36,48,48,72,48,48,1,12,5,10,14,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(policy,'MARKET-GRAPH/1')
hA=schema~encode(A); hB=schema~encode(B); hC=schema~encode(C)
call check schema~difference(hA,hC)~exact,'economic twin remains exact under ML semantics'
call check \schema~difference(hA,hB)~exact,'price lookalike remains structurally different under ML semantics'
g=.MLTemporalPatternGraphAdapter~overlay('market reveal',.array~of(hA,hB),.array~of('A','B'),.array~of('PRIMARY','CONTRAST'))
call check g~seriesCount=8,'A/B overlay contains four channels for each pattern'
call check g~seriesAt(1)~evidence==hA & g~seriesAt(5)~evidence==hB,'graph preserves which temporal hash supplied each channel'
if f=0 then do; say 'PASS MLGraph temporal market 4 assertions'; exit 0; end
say 'FAIL MLGraph temporal market failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraph.cls'
::requires 'OorexxML.cls'
