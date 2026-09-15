t=.array~of(0,1,2,4,5,7,8,10)
price=.array~of(100,102,105,104,108,111,110,114)
relativeA=.array~of(0,.4,.8,.3,1.2,1.7,1.3,2.0)
fxA=.array~of(0,-.2,-.4,-.5,-.3,-.1,.1,.2)
volA=.array~of(18,18,19,20,19,18,19,18)
relativeB=.array~of(0,-.2,-.6,-.9,-.5,-.1,.4,.8)
fxB=.array~of(0,.5,1.1,1.4,1.8,2.1,2.4,2.8)
volB=.array~of(18,20,23,26,25,27,29,31)
names=.array~of('PRICE','RELATIVE','FX','VOL')
weights=.array~of(1,4,4,2)
a=.MLTemporalPatternSeries~new(t,names,.array~of(price,relativeA,fxA,volA),weights,'MARKET-A')
b=.MLTemporalPatternSeries~new(t,names,.array~of(price,relativeB,fxB,volB),weights,'MARKET-B')
p=.MLTemporalPatternPolicy~new(24,32,32,72,36,36,1,8,4,8,10,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(p,'MARKET-MULTI')
d=schema~difference(schema~encode(a),schema~encode(b))
call assert \d~exact,'same nominal price with different economic channels must not be same market pattern'
call assert d~dominantChannel\='PRICE','auxiliary economic state should be able to dominate nominal-price equality'
say 'PASS temporal_pattern_multichannel_market dominant='d~dominantChannel'/'d~dominantKind
exit 0
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
