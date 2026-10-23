call main
exit 0
main:
  identity=.InstrumentationCodec~identity("estate.test","bosh.transport","instance.1","node.1","","transport")
  contexts=.array~of("change://CHG-920","xmpp-session://agent-a")
  observer=.BoshInstrumentationObserver~forIdentity(identity,"BOSH_TRANSPORT","agent-message-77","message-accepted-77",contexts,"bosh-session-77")
  http=.FakeHttp~new
  p=.BoshStreamProvider~new(http,.BoshFixedRequestIdSource~new(40001),observer)
  s=p~connect(.BoshEndpoint~new("https://secret.example/bosh","secret.example"))
  call assert s<>.nil,"open"
  call assert s~send("SECRET-STANZA")=13,"write"
  ignore=s~recv
  call assert s~close,"close"

  snap=observer~snapshot
  samples=snap["samples"]
  call assert metricValue(samples,.BoshInstrumentationMetrics~SESSION_OPEN_TOTAL)=1,"session open metric"
  call assert metricValue(samples,.BoshInstrumentationMetrics~HTTP_EXCHANGE_TOTAL)>=3,"HTTP exchange metric"
  call assert metricValue(samples,.InstrumentationVocabulary~BYTES_OUT_TOTAL)>0,"bytes out metric"
  call assert metricValue(samples,.InstrumentationVocabulary~BYTES_IN_TOTAL)>0,"bytes in metric"
  cap=.BoshInstrumentationObserver~capability(identity)
  call assert cap["commands"]~items=0,"no management commands"

  events=observer~events
  call assert events~items>=2,"bounded source events exposed"
  do e over events
    call assert e["correlation_id"]="agent-message-77","explicit correlation preserved"
    call assert e["causation_id"]="message-accepted-77","explicit causation preserved"
    call assert e["operation_id"]="bosh-session-77","operation id preserved"
    call assert e["context_refs"]~items=2,"context refs preserved"
  end

  registry=.InstrumentationRegistry~new
  registry~register("bosh",observer)
  service=.InstrumentationService~new(registry)
  collector=.InstrumentationCollector~new(40)
  transport=.InstrumentationLocalCollectorTransport~new(.InstrumentationCollectorService~new(collector),"node.1")
  publisher=.InstrumentationPublisher~new("bosh-publisher",service,transport,"noc")
  call assert publisher~publish~ok,"publication accepted"
  view=.InstrumentationCorrelationView~new(collector)
  group=view~byId("agent-message-77")
  call assert group<>.nil,"explicit correlation group exists"
  call assert group["event_count"]>=2,"BOSH events grouped only by supplied correlation"
  call assert view~byId("invented-correlation")=.nil,"no inferred correlation"

  text=cap~string||snap~string||events~string
  call assert pos("SECRET-STANZA",text)=0,"payload absent from instrumentation"
  call assert pos("secret.example",text)=0,"endpoint absent from instrumentation"
  say "PASS BOSH Instrumentation Mesh dev8 explicit correlation integration"
  return

metricValue: procedure
  use strict arg samples,name
  do s over samples
    if s["name"]=name then return s["value"]
  end
  return 0

assert: procedure
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  say "PASS" label
  return

::class FakeHttp subclass BoshHttpExchangeProvider
::method init; expose count; count=0
::method exchange
  expose count
  use strict arg uri, method, headers, body
  count+=1
  if count=1 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind' sid='S5'/>")
  if pos("type='terminate'",body)>0 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'/>")
  return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><ok/></body>")

::requires "BoshInstrumentationAdapter.cls"
::requires "InstrumentationCorrelation.cls"
