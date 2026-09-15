cb=.TestCallback~new
reg=.ApiCallbackRegistry~new~register('done',cb,'DONE')
transport=.FakeTransport~new

nodes=.ApiEgressRegistry~new
uk=.ApiEgressNode~new('NODE-UK',.array~of('GB'),.array~new,.array~of('PUBLIC'),.array~of('DIRECT'),.array~of('LOW_LATENCY'),4,1,'proof:uk')
us=.ApiEgressNode~new('NODE-US',.array~of('US'),.array~new,.array~of('PUBLIC'),.array~of('DIRECT'),.array~of('US_EGRESS'),4,1,'proof:us')
z=.ApiEgressNode~new('NODE-Z',.array~of('GB'),.array~of('LEGAL-EU'),.array~of('VPN'),.array~of('CONTROLLED'),.array~of('LEGAL_RESEARCH'),2,1,'proof:z')
nodes~advertise(uk); nodes~advertise(us); nodes~advertise(z)
sessions=.ApiSessionManager~new(nodes,'NODE-UK')
client=.ApiClient~new(transport,.nil,reg,.nil,sessions)

client~submit(.ApiRequest~new('bulk','POST','https://example.invalid',.nil,'x','SOURCE_BULK',100,5000000,100000,'done'))
client~submit(.ApiRequest~new('urgent','POST','https://example.invalid',.nil,'x','INTERACTIVE',50,1000000,2000000,'done'))
client~submit(.ApiRequest~new('news','GET','https://example.invalid',.nil,'','NEWS_INGEST',100,2000000,100000,'done'))
r1=client~executeNext
if r1~requestId \= 'urgent' then call fail 'priority did not select interactive work first'
if r1~egressNodeId \= 'NODE-UK' then call fail 'unconstrained work should prefer local node'
r2=client~executeNext
if r2~requestId \= 'bulk' then call fail 'source bulk should outrank news ingest at supplied priorities'
r3=client~executeNext
if cb~count \= 3 then call fail 'callback count'
if client~rateWindow~remaining \= 97 then call fail 'rate monitoring'

usRoute=.ApiRouteRequirement~new('US')
client~submit(.ApiRequest~new('us-required','GET','https://example.invalid',.nil,'','INTERACTIVE',50,1000000,1000000,'done',.nil,usRoute,'NODE-UK'))
r4=client~executeNext
if r4~egressNodeId \= 'NODE-US' then call fail 'US route requirement not enforced'
if r4~sessionId = '' then call fail 'routed request missing session id'

vpnRoute=.ApiRouteRequirement~new('','LEGAL-EU','VPN','CONTROLLED',.array~of('LEGAL_RESEARCH'))
client~submit(.ApiRequest~new('vpn-required','GET','https://example.invalid',.nil,'','RESEARCH',80,1000000,500000,'done',.nil,vpnRoute,'NODE-UK'))
r5=client~executeNext
if r5~egressNodeId \= 'NODE-Z' then call fail 'VPN route requirement not enforced'

missingRoute=.ApiRouteRequirement~new('JP','NONEXISTENT')
client~submit(.ApiRequest~new('no-route','GET','https://example.invalid',.nil,'','INTERACTIVE',50,1000000,1000000,'done',.nil,missingRoute,'NODE-UK'))
r6=client~executeNext
if r6~errorCode \= 'ROUTE_UNAVAILABLE' then call fail 'missing route did not fail closed'
if transport~count \= 5 then call fail 'route failure touched transport'
if sessions~activeCount \= 0 then call fail 'sessions were not released'
if cb~count \= 6 then call fail 'routed callback count'

/* Direct execution is for protocol adapters that already own one request. */
direct=.ApiRequest~new('direct','GET','https://example.invalid',.nil,'','CONTROL',10,1000,1000,'done')
dr=client~execute(direct)
if dr~requestId \= 'direct' then call fail 'direct execute returned wrong request'
if transport~count \= 6 then call fail 'direct execute did not reach transport'
if cb~count \= 7 then call fail 'direct execute callback count'

say 'PASS api client v0.3 priority routing sessions callbacks rate monitoring direct execution'
exit 0
fail: procedure
 parse arg m
 say 'FAIL' m
 exit 1

::class FakeTransport subclass ApiTransport
::attribute count get
::method init
 expose count
 count=0
::method execute
 expose count
 use arg request,session=.nil
 count+=1
 h=.directory~new; h['x-ratelimit-limit']=100; h['x-ratelimit-remaining']=97
 return .ApiResponse~new(request~id,200,h,'{}',1)
::class TestCallback
::attribute count get
::method init
 expose count
 count=0
::method done
 expose count
 use arg response,request
 count+=1

::requires 'src/ApiClient.cls'
