parse arg bridgeDir caFile
cfg=.ApiHttpTransportConfig~new
cfg~bridgeDirectory=bridgeDir
cfg~caFile=caFile
cfg~verifyPeer=.true
cfg~readTimeout=5
cfg~writeTimeout=5
transport=.ApiHttpsTransport~new(cfg)
headers=.directory~new
r=.ApiRequest~new('r1','GET','https://localhost:18443/hello',headers)
resp=transport~execute(r)
if \resp~ok then do; say 'FAIL GET' resp~errorCode resp~headers['x-oorexx-transport-detail']; exit 2; end
if resp~body<>'{"hello":"world"}' then do; say 'FAIL BODY' resp~body; exit 3; end
h=.directory~new; h['content-type']='application/json'
p=.ApiRequest~new('r2','POST','https://localhost:18443/submit',h,'{"data":["x"]}')
pr=transport~execute(p)
if \pr~ok then do; say 'FAIL POST' pr~errorCode pr~headers['x-oorexx-transport-detail']; exit 4; end
doc=.json~fromJSON(pr~body)
if doc['event_id']<>'evt1' then do; say 'FAIL EVENT ID'; exit 5; end
g=.ApiRequest~new('r3','GET','https://localhost:18443/events/evt1')
gr=transport~execute(g)
if \gr~ok then do; say 'FAIL SSE GET' gr~errorCode gr~headers['x-oorexx-transport-detail']; exit 6; end
events=.ApiSseParser~parse(gr~body)
if events~items<>2 then do; say 'FAIL SSE COUNT' events~items; exit 7; end
if events[2]~event<>'complete' | events[2]~data<>'["done"]' then do; say 'FAIL SSE FINAL' events[2]~event events[2]~data; exit 8; end
transport~close
say 'PASS NATIVE HTTPS + JSON + CHUNKED SSE'
::requires 'ApiHttpTransport.cls'
::requires 'json.cls'
