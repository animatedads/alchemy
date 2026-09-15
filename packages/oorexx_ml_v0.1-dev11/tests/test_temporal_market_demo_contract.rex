names=.array~of('PRICE','RELATIVE','FX','VOL'); weights=.array~of(1,4,4,2)
t=.array~of(0,1,2,4,5,7,8,10,13,15)
priceA=.array~of(100,102,105,104,108,111,110,114,117,121)
relA=.array~of(0,.3,.8,.4,1.1,1.7,1.4,2.1,2.5,3.0)
fxA=.array~of(0,-.2,-.4,-.6,-.5,-.2,.1,.3,.2,0)
volA=.array~of(18,18,19,20,19,18,19,18,17,18)
a=.MLTemporalPatternSeries~new(t,names,.array~of(priceA,relA,fxA,volA),weights,'A')
priceB=.array~of(100,102.1,105.1,104.2,108.2,111.2,110.1,114.1,117.1,121.1)
relB=.array~of(0,-.3,-.8,-1.0,-.7,-.2,.2,.7,1.0,1.2)
fxB=.array~of(0,.4,.9,1.2,1.6,2.0,2.4,2.8,3.0,3.4)
volB=.array~of(18,20,23,26,25,28,30,32,31,33)
b=.MLTemporalPatternSeries~new(t,names,.array~of(priceB,relB,fxB,volB),weights,'B')
tc=.array~new; do x over t; tc~append(100+2*x); end
pc=.array~new; do x over priceA; pc~append(250+2.5*(x-100)); end
rc=.array~new; do x over relA; rc~append(50+7*x); end
fc=.array~new; do x over fxA; fc~append(-20+3*x); end
vc=.array~new; do x over volA; vc~append(200+4*(x-17)); end
c=.MLTemporalPatternSeries~new(tc,names,.array~of(pc,rc,fc,vc),weights,'C')
td=.array~of(0,1,2,4,5,9,10,11,13,15)
d=.MLTemporalPatternSeries~new(td,names,.array~of(priceA,relA,fxA,volA),weights,'D')
policy=.MLTemporalPatternPolicy~new(36,48,48,72,48,48,1,12,5,10,14,.true,.true,1)
s=.MLCylindricalTemporalPatternSchema~new(policy,'MARKET-DEMO')
ha=s~encode(a); hab=s~difference(ha,s~encode(b)); hac=s~difference(ha,s~encode(c)); had=s~difference(ha,s~encode(d))
call assert hac~exact,'economic twin must remain exact demo match'
call assert \hab~exact,'nominal-price lookalike must separate under economic channels'
call assert hab~dominantChannel\='PRICE','price must not dominate the lookalike separation'
call assert hab~dominantDelta>had~dominantDelta,'economic-state divergence should outrank one local timing shock in demo policy'
call assert had~timeMax>0 | had~elevationMax>0,'timing shock must carry temporal evidence'
say 'PASS temporal_market_demo_contract A/B='hab~dominantDelta 'A/C='hac~dominantDelta 'A/D='had~dominantDelta
exit 0
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
