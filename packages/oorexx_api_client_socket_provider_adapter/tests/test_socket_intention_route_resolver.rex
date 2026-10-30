call main
exit 0

main:
  route=.ApiRouteRequirement~new("GB","CORP","PUBLIC","STANDARD",.array~of("OUTBOUND"))
  md=.directory~new
  md["socketLogicalName"]="api.service"
  request=.ApiRequest~new("r1","GET","https://example.test/resource",.nil,"","INTERACTIVE",50,1000,1000,"",md,route,"node-a")
  url=.ApiUrl~new(request~url)

  xtp=.SocketAddresses~xtp("GRID.API.SERVICE",.false,"api.service")
  tcp=.SocketAddresses~tcp("192.0.2.44",443,"api.service")
  port=.FakeIntentionPort~new(.array~of(xtp,tcp))
  resolver=.ApiSocketIntentionRouteResolver~new(port)

  a1=resolver~resolve(url,request,.nil)
  call assertTrue a1==xtp,"first fresh negotiation returns first selected address"
  call assertEq 1,resolver~generation,"generation one"
  n1=resolver~lastNegotiationRequest
  call assertEq "api.service",n1~logicalName,"semantic logical name from request metadata"
  call assertEq .SocketRole~SENDER,n1~role,"sender role"
  call assertTrue n1~requireStream,"stream required"
  call assertTrue \n1~requireSecure,"lower secure socket not required because API Client owns TLS"
  call assertTrue n1~schemeAllowed(.SocketScheme~XTP),"XTP raw stream allowed"
  call assertTrue n1~schemeAllowed(.SocketScheme~TCP),"TCP raw stream allowed"
  call assertTrue \n1~schemeAllowed(.SocketScheme~TLS),"TLS socket excluded to avoid TLS-inside-TLS"
  call assertTrue n1~metadata["apiRouteRequirement"]==route,"exact ApiRouteRequirement preserved"
  call assertTrue n1~metadata["apiRequest"]==request,"exact ApiRequest preserved"
  call assertTrue port~lastContext["apiRouteRequirement"]==route,"context preserves exact route requirement"

  a2=resolver~resolve(url,request,.nil)
  call assertTrue a2==tcp,"second resolve renegotiates instead of caching"
  call assertEq 2,resolver~generation,"generation two"
  call assertEq 2,port~count,"intention port called on every resolve"

  noOffer=.FakeNoOfferPort~new
  failed=.ApiSocketIntentionRouteResolver~new(noOffer)
  call assertTrue failed~resolve(url,request,.nil)==.nil,"no current offer fails closed"
  call assertEq "SOCKET_NEGOTIATION_NO_OFFER",failed~lastError,"no-offer error retained"

  fallbackRequest=.ApiRequest~new("r2","GET","https://fallback.example/path")
  one=.FakeIntentionPort~new(.array~of(tcp))
  fallback=.ApiSocketIntentionRouteResolver~new(one)
  ignore=fallback~resolve(.ApiUrl~new(fallbackRequest~url),fallbackRequest,.nil)
  call assertEq "fallback.example",fallback~lastNegotiationRequest~logicalName,"URL host is bounded fallback logical name"

  evidence=.directory~new
  evidence["route.attested"]=.true
  evidence["service.protection"]="ENCRYPT"
  protectedXtp=.SocketAddresses~xtp("GRID.API.PROTECTED",.false,"api.service",evidence)
  requirements=.directory~new
  requirements["route.attested"]=.true
  requirements["service.protection"]="ENCRYPT"
  policy=.ApiSocketRequiredMetadataPolicy~new(requirements)
  protectedPort=.FakeIntentionPort~new(.array~of(protectedXtp))
  protectedResolver=.ApiSocketIntentionRouteResolver~new(protectedPort,.nil,.nil,policy)
  admitted=protectedResolver~resolve(url,request,.nil)
  call assertTrue admitted==protectedXtp,"attested selected address admitted"
  call assertTrue policy~lastAddress==protectedXtp,"policy receives exact selected SocketAddress"
  call assertTrue policy~lastRequest==request,"policy receives exact ApiRequest"
  call assertTrue policy~lastSelection==protectedResolver~lastSelection,"policy receives exact selection evidence"

  weakEvidence=.directory~new
  weakEvidence["route.attested"]=.true
  weakEvidence["service.protection"]="AUTHENTICATE"
  weakXtp=.SocketAddresses~xtp("GRID.API.WEAK",.false,"api.service",weakEvidence)
  weakPolicy=.ApiSocketRequiredMetadataPolicy~new(requirements)
  weakResolver=.ApiSocketIntentionRouteResolver~new(.FakeIntentionPort~new(.array~of(weakXtp)),.nil,.nil,weakPolicy)
  call assertTrue weakResolver~resolve(url,request,.nil)==.nil,"weaker selected route fails closed"
  call assertEq "SOCKET_ROUTE_METADATA_MISMATCH",weakResolver~lastError,"mismatched route evidence retained"
  call assertEq "service.protection",weakPolicy~mismatchedKey,"mismatched evidence key retained"

  missingEvidence=.directory~new
  missingEvidence["route.attested"]=.true
  missingXtp=.SocketAddresses~xtp("GRID.API.MISSING",.false,"api.service",missingEvidence)
  missingPolicy=.ApiSocketRequiredMetadataPolicy~new(requirements)
  missingResolver=.ApiSocketIntentionRouteResolver~new(.FakeIntentionPort~new(.array~of(missingXtp)),.nil,.nil,missingPolicy)
  call assertTrue missingResolver~resolve(url,request,.nil)==.nil,"missing selected route evidence fails closed"
  call assertEq "SOCKET_ROUTE_METADATA_MISSING",missingResolver~lastError,"missing route evidence retained"
  call assertEq "service.protection",missingPolicy~missingKey,"missing evidence key retained"

  say "PASS API Client Socket Intention dynamic route resolver and admission policy"
  return

assertEq: procedure
  use strict arg expected,actual,label
  if expected<>actual then do
    say "FAIL:" label "expected="expected "actual="actual
    exit 1
  end
  say "PASS" label
  return

assertTrue: procedure
  use strict arg ok,label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  say "PASS" label
  return

::class FakeIntentionPort public
::method init
  expose addresses count lastRequest lastContext
  use strict arg addresses
  count=0; lastRequest=.nil; lastContext=.nil
::attribute count get
::attribute lastRequest get
::attribute lastContext get
::method negotiate
  expose addresses count lastRequest lastContext
  use strict arg request, context=.nil
  count+=1
  lastRequest=request
  lastContext=context
  index=count
  if index>addresses~items then index=addresses~items
  address=addresses[index]
  offer=.SocketNegotiationOffer~new("offer-"||count,address,10,"REMOTE",.true,"test","fake")
  return .SocketNegotiationSelection~new(.SocketNegotiationStatus~SELECTED,request,offer,"selected")

::class FakeNoOfferPort public
::method negotiate
  use strict arg request, context=.nil
  return .SocketNegotiationSelection~new(.SocketNegotiationStatus~NO_OFFER,request,.nil,"none")

::requires "ApiClientSocketProviderAdapter.cls"
