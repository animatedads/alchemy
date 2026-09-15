parse arg bridgeDir caFile
cfg=.ApiHttpTransportConfig~new
cfg~bridgeDirectory=bridgeDir
cfg~h2BridgeFile=bridgeDir || '/api_h2.bridge.json'
cfg~caFile=caFile
cfg~verifyPeer=.true
cfg~readTimeout=5; cfg~writeTimeout=5
cfg~httpVersionPolicy='HTTP2_REQUIRED'
cfg~followRedirects=.true
cfg~maxRedirects=5
transport=.ApiHttpsTransport~new(cfg)
r=.ApiRequest~new('h2-1','GET','https://localhost:18444/hello')
resp=transport~execute(r)
if \resp~ok then do; say 'FAIL H2 GET' resp~errorCode resp~headers['x-oorexx-transport-detail']; exit 2; end
if resp~httpVersion<>'h2' then do; say 'FAIL H2 ALPN' resp~httpVersion; exit 3; end
if resp~body<>'{"hello":"h2"}' then do; say 'FAIL H2 BODY' resp~body; exit 4; end
rr=.ApiRequest~new('h2-r','GET','https://localhost:18444/redirect')
rp=transport~execute(rr)
if \rp~ok | rp~redirectCount<>1 then do; say 'FAIL REDIRECT' rp~errorCode rp~redirectCount; exit 5; end
if rp~finalUrl<>'https://localhost:18444/hello' then do; say 'FAIL FINAL URL' rp~finalUrl; exit 6; end
loop=.ApiRequest~new('h2-loop','GET','https://localhost:18444/loop')
lp=transport~execute(loop)
if lp~errorCode<>'REDIRECT_LOOP' then do; say 'FAIL LOOP POLICY' lp~errorCode; exit 7; end
cross=.ApiRequest~new('h2-cross','GET','https://localhost:18444/cross')
cp=transport~execute(cross)
if cp~errorCode<>'REDIRECT_CROSS_ORIGIN_FORBIDDEN' then do; say 'FAIL CROSS ORIGIN POLICY' cp~errorCode; exit 8; end
transport~close
say 'PASS HTTP/2 ALPN NGHTTP2 REDIRECT POLICY'
::requires 'ApiHttpTransport.cls'
