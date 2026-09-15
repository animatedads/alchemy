parse arg root
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "ABILITY HTTP SERVER V0.7 ACCEPTANCE START"
  verifier=.RuntimePinnedSourceVerifier~new
  kernel=.RuntimeKernel~new(verifier)
  data=stage(kernel,verifier,root||"/fixtures/modules/HttpData_v1.cls","http.data","CAPABILITY","http:data:1","HttpDataCapability")
  rules=stage(kernel,verifier,root||"/fixtures/modules/HttpRules_v1.cls","http.rules","RULE","http:rules:1","HttpRulesCapability")
  call ok kernel~activate("prod","http.data",data~generationId),"activate data"
  call ok kernel~activate("prod","http.rules",rules~generationId),"activate rules"
  ar=.AbilityRegistry~new(kernel)
  p=profile(data~artifactId,rules~artifactId)
  sr=ar~stage("prod",p); call ok sr,"stage profile"; ag=sr~value
  call ok ar~activate("prod","client-http",ag~generationId),"activate profile"
  limited=limitedProfile(data~artifactId)
  lr=ar~stage("prod",limited); call ok lr,"stage limited profile"; lag=lr~value
  call ok ar~activate("prod","client-other",lag~generationId),"activate limited profile"
  keys=.AbilityCredentialStore~new
  call ok keys~register("k1","s3cret","prod","client-http"),"register key"
  call ok keys~register("k2","other","prod","client-other"),"register second key"
  store=.AbilityResultStore~new(300,100)
  router=.AbilityHttpRouter~new(ar,keys,store)
  server=.AbilityHttpServer~new(router,"127.0.0.1",0,.AbilityHttpLimits~new(2048,8192,32,1024),32)
  activity=server~start("serve")
  do i=1 to 500 while \server~listening; call SysSleep 0.01; end
  call yes server~listening,"server listening"
  port=server~port
  auth="Authorization: Bearer ab1.k1.s3cret"
  otherAuth="Authorization: Bearer ab1.k2.other"

  r=req(port,"GET /v1/health HTTP/1.1",.array~of("Host: localhost"),""); call eq 200,status(r),"health"
  r=req(port,"GET /v1/abilities HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 200,status(r),"abilities"
  aj=json(r)~at("abilities"); call eq 3,aj~items,"ability catalogue count"
  qtool=findAbility(aj,"query"); call eq "/v1/queries",qtool~at("invoke_uri"),"query invoke uri"; call no qtool~at("wlu_admission")~value,"query not WLU-managed without bridge"; call eq "materialized-query",qtool~at("result_mode"),"query result mode"; call eq "object",qtool~at("input_schema")~at("type"),"query input schema"; call eq "q",qtool~at("input_schema")~at("required")~at(1),"query required q"
  etool=findAbility(aj,"echo.custom"); call eq "/v1/abilities/echo.custom",etool~at("invoke_uri"),"generic invoke uri"; call eq "inline",etool~at("result_mode"),"generic result mode"; call eq "string",etool~at("output_schema")~at("properties")~at("echo")~at("type"),"echo output schema"
  r=req(port,"GET /v1/openapi.json HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 200,status(r),"openapi"
  oj=json(r); call eq "3.2.0",oj~at("openapi"),"openapi version"
  px=oj~at("x-oorexx-profile"); call eq "client-http",px~at("client_id"),"openapi client scoped"; call eq ag~generationId,px~at("ability_generation"),"openapi generation scoped"
  paths=oj~at("paths"); call yes paths~hasIndex("/v1/queries"),"query path advertised"; call yes paths~hasIndex("/v1/evaluations"),"evaluation path advertised"; call yes paths~hasIndex("/v1/abilities/echo.custom"),"exact dynamic ability path advertised"; call no paths~hasIndex("/v1/abilities/{abilityId}"),"ambiguous generic OpenAPI path omitted"
  oop=paths~at("/v1/openapi.json")~at("get"); call yes oop~at("responses")~hasIndex("304"),"openapi 304 advertised"; call eq "If-None-Match",oop~at("parameters")~at(1)~at("name"),"openapi conditional header advertised"
  call yes paths~at("/v1/queries")~at("post")~at("responses")~hasIndex("429"),"OpenAPI WLU admission response advertised"
  qschema=paths~at("/v1/queries")~at("post")~at("requestBody")~at("content")~at("application/json")~at("schema"); call eq "q",qschema~at("required")~at(1),"OpenAPI query required q"; call no qschema~at("additionalProperties")~value,"OpenAPI query rejects extras"
  eschema=paths~at("/v1/abilities/echo.custom")~at("post")~at("requestBody")~at("content")~at("application/json")~at("schema"); call eq "message",eschema~at("required")~at(1),"OpenAPI echo required message"
  eout=paths~at("/v1/abilities/echo.custom")~at("post")~at("responses")~at("200")~at("content")~at("application/json")~at("schema")~at("properties")~at("result"); call eq "string",eout~at("properties")~at("echo")~at("type"),"OpenAPI exact echo output schema"
  ores=oj~at("x-oorexx-resources"); call eq 1,ores~items,"one resource in openapi"; call eq "orders",ores~at(1)~at("name"),"resource name in openapi"
  orules=oj~at("x-oorexx-rules"); call eq 1,orules~items,"one rule in openapi"; call eq "customer-policy",orules~at(1)~at("name"),"rule name in openapi"
  et=header(r,"etag"); call yes et<>"","openapi etag"
  r=req(port,"GET /v1/openapi.json HTTP/1.1",.array~of("Host: localhost",auth,"If-None-Match: "||et),""); call eq 304,status(r),"openapi conditional get"; call eq "",body(r),"304 empty body"
  r=req(port,"GET /v1/openapi.json HTTP/1.1",.array~of("Host: localhost"),""); call eq 401,status(r),"openapi requires auth"
  r=req(port,"GET /v1/openapi.json HTTP/1.1",.array~of("Host: localhost",otherAuth),""); call eq 200,status(r),"limited openapi"
  loj=json(r); lpaths=loj~at("paths"); call no lpaths~hasIndex("/v1/queries"),"ungranted query omitted"; call no lpaths~hasIndex("/v1/evaluations"),"ungranted evaluation omitted"; call yes lpaths~hasIndex("/v1/abilities/echo.custom"),"limited exact ability path"
  lout=lpaths~at("/v1/abilities/echo.custom")~at("post")~at("x-oorexx-output-schema"); call eq "integer",lout~at("properties")~at("echo")~at("type"),"limited profile has independent output schema"
  call no header(r,"etag")=et,"different profile has different etag"

  b='{"q":1}'
  h=.array~of("Host: localhost",auth,"Content-Type: application/json","Content-Length: "||b~length)
  r=req(port,"POST /v1/queries HTTP/1.1",h,b); call eq 422,status(r),"query string schema enforced"
  b='{"q":"open orders","extra":true}'
  h=.array~of("Host: localhost",auth,"Content-Type: application/json","Content-Length: "||b~length)
  r=req(port,"POST /v1/queries HTTP/1.1",h,b); call eq 422,status(r),"query additional properties schema enforced"

  b='{"q":"open orders"}'
  h=.array~of("Host: localhost",auth,"Content-Type: application/json","Content-Length: "||b~length)
  r=req(port,"POST /v1/queries HTTP/1.1",h,b); call eq 201,status(r),"query created"
  j=json(r); queryId=j~at("id"); call prefix "qry-",queryId,"query id"
  call eq 2,j~at("row_count"),"query row count"; call eq 2,j~at("evidence_count"),"query evidence count"
  q=j~at("result"); call eq "DATA-ONE",q~at("generation"),"query generation"; call eq 1,q~at("invocation_count"),"query invoked once"
  call no q~at("rules_visible")~value,"query cannot see rules"
  call eq data~generationId,q~at("runtime_generation"),"query sees exact allowed data generation evidence"
  call eq data~artifactId,q~at("runtime_artifact"),"query sees exact allowed data artifact evidence"
  call no q~at("rules_evidence_visible")~value,"query cannot see undeclared rules execution evidence"
  call no q~at("rank")~isa(.JSONBoolean),"numeric one remains numeric"
  firstEv=q~at("rows")~at(1)~at("amount_evidence")~at("evidence_id")

  r=req(port,"GET /v1/queries/"||queryId||" HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 200,status(r),"get query"
  r=req(port,"GET /v1/queries/"||queryId||"/rows?limit=1 HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 200,status(r),"page one"
  pj=json(r); call eq 1,pj~at("items")~items,"page one count"; call eq "c.1",pj~at("next_cursor"),"next cursor"
  r=req(port,"GET /v1/queries/"||queryId||"/rows?cursor=c.1&limit=1 HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 200,status(r),"page two"; pj=json(r); call eq 2,pj~at("items")~at(1)~at("id"),"page two row"
  r=req(port,"GET /v1/evidence/"||firstEv||" HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 200,status(r),"evidence detail"; ej=json(r); call eq 10,ej~at("value"),"evidence value"; call eq "/fixture/orders/10",ej~at("source")~at("path"),"evidence path"
  r=req(port,"GET /v1/evidence/"||firstEv||" HTTP/1.1",.array~of("Host: localhost",otherAuth),""); call eq 404,status(r),"cross-client evidence hidden"
  r=req(port,"GET /v1/queries/"||queryId||" HTTP/1.1",.array~of("Host: localhost",otherAuth),""); call eq 404,status(r),"cross-client result hidden"
  r=req(port,"GET /v1/queries/"||queryId||"/rows?cursor=broken HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 400,status(r),"bad cursor"
  r=req(port,"GET /v1/queries/"||queryId||"/rows?limit=1&limit=2 HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 400,status(r),"duplicate limit"

  b='{"message":7}'
  h=.array~of("Host: localhost",auth,"Content-Type: application/json","Content-Length: "||b~length)
  r=req(port,"POST /v1/abilities/echo.custom HTTP/1.1",h,b); call eq 422,status(r),"generic input schema enforced"
  b='{"message":"after traversal"}'
  h=.array~of("Host: localhost",auth,"Content-Type: application/json","Content-Length: "||b~length)
  r=req(port,"POST /v1/abilities/echo.custom HTTP/1.1",h,b); call eq 200,status(r),"generic ability"
  e=json(r)~at("result"); call eq 2,e~at("invocation_count"),"paging/evidence did not re-execute query"
  oh=.array~of("Host: localhost",otherAuth,"Content-Type: application/json","Content-Length: "||b~length)
  r=req(port,"POST /v1/abilities/echo.custom HTTP/1.1",oh,b); call eq 500,status(r),"declared output schema enforced"
  r=req(port,"POST /v1/abilities/query HTTP/1.1",h,b); call eq 404,status(r),"query has no inline alternate route"
  r=req(port,"POST /v1/abilities/evaluate HTTP/1.1",h,b); call eq 404,status(r),"evaluation has no inline alternate route"

  b='{"action":"SELL_BAG"}'
  h=.array~of("Host: localhost",auth,"Content-Type: application/json","Content-Length: "||b~length)
  r=req(port,"POST /v1/evaluations HTTP/1.1",h,b); call eq 201,status(r),"evaluation created"
  j=json(r); evalId=j~at("id"); call prefix "eval-",evalId,"evaluation id"; call eq "PROHIBITED",j~at("result")~at("disposition"),"authority result"
  r=req(port,"GET /v1/evaluations/"||evalId||"/evidence HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 200,status(r),"evaluation evidence"; call eq 0,json(r)~at("evidence")~items,"evaluation evidence empty"

  r=req(port,"DELETE /v1/evaluations/"||evalId||" HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 200,status(r),"delete evaluation"

  r=req(port,"DELETE /v1/queries/"||queryId||" HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 200,status(r),"delete query"
  r=req(port,"GET /v1/queries/"||queryId||" HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 404,status(r),"deleted query gone"
  r=req(port,"GET /v1/evidence/"||firstEv||" HTTP/1.1",.array~of("Host: localhost",auth),""); call eq 404,status(r),"deleted evidence gone"

  call ok server~stop,"stop"
  do i=1 to 500 while server~listening; call SysSleep 0.01; end
  call no server~listening,"stopped"

  shortStore=.AbilityResultStore~new(1,10)
  sessResult=ar~acquire("prod","client-http"); call ok sessResult,"acquire short session"; sess=sessResult~value
  call eq 1,ag~leaseCount,"session lease held"
  made=shortStore~create("query",sess,"query",.directory~new); call ok made,"short result"
  call SysSleep 1.1
  expired=shortStore~getResult("client-http",made~value~resultId,"query"); call no expired~ok,"short result expires"
  call eq 0,ag~leaseCount,"expiry releases session"

  say "  port="||port
  say "  query_id="||queryId
  say "  evidence_id="||firstEv
  say "  profile_generation="||ag~generationId
  say "ABILITY HTTP SERVER V0.7 ACCEPTANCE: OK"
  return

profile:
  procedure
  use arg da,ra
  rb=.array~of(.AbilityRuntimeBinding~new("data","http.data",da),.AbilityRuntimeBinding~new("rules","http.rules",ra))
  qin=schemaValue('{"type":"object","required":["q"],"properties":{"q":{"type":"string","minLength":1}},"additionalProperties":false}')
  ein=schemaValue('{"type":"object","required":["action"],"properties":{"action":{"type":"string","minLength":1}},"additionalProperties":false}')
  eout=schemaValue('{"type":"object","required":["disposition"],"properties":{"disposition":{"type":"string"}},"additionalProperties":true}')
  cin=schemaValue('{"type":"object","required":["message"],"properties":{"message":{"type":"string","minLength":1,"maxLength":100}},"additionalProperties":false}')
  cout=schemaValue('{"type":"object","required":["echo","invocation_count"],"properties":{"echo":{"type":"string"},"invocation_count":{"type":"integer"},"rules_visible":{"type":"boolean"}},"additionalProperties":true}')
  ab=.array~of(.AbilityDescriptor~new("query","QUERY",.array~of("data"),.true,"query",qin,.AbilityJsonSchema~any), -
               .AbilityDescriptor~new("evaluate","EVALUATE",.array~of("rules","data"),.true,"evaluate",ein,eout), -
               .AbilityDescriptor~new("echo.custom","CUSTOM",.array~of("data"),.true,"generic dynamic ability",cin,cout))
  db=.array~of(.AbilityDataBinding~new("orders","data","customer_orders","READ"))
  rr=.array~of(.AbilityRuleBinding~new("customer-policy","rules","customer-policy"))
  return .AbilityProfileRevision~new("http-bot","1","client-http",rb,ab,db,rr,"http profile")

limitedProfile:
  procedure
  use arg da
  rb=.array~of(.AbilityRuntimeBinding~new("data","http.data",da))
  cin=schemaValue('{"type":"object","required":["message"],"properties":{"message":{"type":"string"}},"additionalProperties":false}')
  badout=schemaValue('{"type":"object","required":["echo"],"properties":{"echo":{"type":"integer"}},"additionalProperties":true}')
  ab=.array~of(.AbilityDescriptor~new("echo.custom","CUSTOM",.array~of("data"),.true,"limited generic ability",cin,badout))
  db=.array~of(.AbilityDataBinding~new("orders","data","customer_orders","READ"))
  return .AbilityProfileRevision~new("limited-bot","1","client-other",rb,ab,db,.array~new,"limited profile")

schemaValue:
  procedure
  use arg text
  schemaParse=.AbilityJsonSchema~fromJson(text)
  if \schemaParse~ok then do; say "FAILED: schema fixture" schemaParse~code schemaParse~detail; exit 96; end
  return schemaParse~value
stage:
  procedure
  use arg kernel,verifier,path,id,kind,aid,entry
  s=.RuntimeSourceLoader~readFile(path); call ok s,"read fixture"; call ok verifier~pin(aid,s~value),"pin"
  a=.RuntimeArtifact~new(id,kind,"1.0.0",aid,entry,s~value); r=kernel~stage("prod",a); call ok r,"stage"; return r~value
req:
  procedure
  use arg port,line,headers,body
  c="0d0a"x; text=line||c
  do i=1 to headers~items; text=text||headers~at(i)||c; end
  return raw(port,text||c||body)
raw:
  procedure
  use arg port,text
  s=.Socket~new; if s~connect(.InetAddress~new("127.0.0.1",port))<0 then exit 90
  off=1
  do while off<=text~length; n=s~send(substr(text,off)); if n==.nil then leave; if n<=0 then leave; off=off+n; end
  out=""
  do forever; x=s~recv(4096); if x==.nil then leave; if x=="" then leave; out=out||x; end
  s~close; return out
status:
  procedure
  use arg r; p=pos("0d0a"x,r); if p=0 then return -1; return word(left(r,p-1),2)
body:
  procedure
  use arg r; z="0d0a0d0a"x; p=pos(z,r); if p=0 then return ""; return substr(r,p+z~length)
json:
  procedure
  use arg r; return .JSON~fromJSON(body(r))
findAbility:
  procedure
  use arg items,id
  do i=1 to items~items
    if items~at(i)~at("id")=id then return items~at(i)
  end
  say "FAILED: ability missing" id; exit 97
header:
  procedure
  use arg r,name
  c="0d0a"x; endHeaders="0d0a0d0a"x; p=pos(endHeaders,r); if p=0 then return ""
  head=left(r,p-1); target=name~lower; start=1
  do forever
    e=pos(c,head,start); if e=0 then line=substr(head,start); else line=substr(head,start,e-start)
    colon=pos(":",line)
    if colon>1 then do; n=left(line,colon-1)~strip~lower; if n=target then return substr(line,colon+1)~strip; end
    if e=0 then leave; start=e+c~length
  end
  return ""
contains:
  procedure
  use arg a,v,l
  do i=1 to a~items; if a~at(i)==v then return; end
  say "FAILED:" l "missing="v; exit 96
ok:
  procedure
  use arg r,l; if \r~ok then do; say "FAILED:" l r~code r~detail; exit 91; end; return
eq:
  procedure
  use arg e,a,l; if e\==a then do; say "FAILED:" l "expected="e "actual="a; exit 92; end; return
yes:
  procedure
  use arg v,l; if \v then do; say "FAILED:" l; exit 93; end; return
no:
  procedure
  use arg v,l; if v then do; say "FAILED:" l; exit 94; end; return
prefix:
  procedure
  use arg p,v,l; if left(v,p~length)\==p then do; say "FAILED:" l "value="v; exit 95; end; return

::requires "AbilityHttpServer.cls"
