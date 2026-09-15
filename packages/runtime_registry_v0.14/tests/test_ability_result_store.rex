parse arg root
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "ABILITY RESULT STORE V0.1 START"
  verifier=.RuntimePinnedSourceVerifier~new
  kernel=.RuntimeKernel~new(verifier)
  data=stage(kernel,verifier,root||"/fixtures/modules/HttpData_v1.cls")
  call ok kernel~activate("prod","http.data",data~generationId),"activate data"
  ar=.AbilityRegistry~new(kernel)
  rb=.array~of(.AbilityRuntimeBinding~new("data","http.data",data~artifactId))
  ab=.array~of(.AbilityDescriptor~new("query","QUERY",.array~of("data"),.true,"query"))
  db=.array~of(.AbilityDataBinding~new("orders","data","customer_orders","READ"))
  p=.AbilityProfileRevision~new("result-bot","1","client-result",rb,ab,db,.array~new,"result profile")
  st=ar~stage("prod",p); call ok st,"stage profile"; ag=st~value
  call ok ar~activate("prod","client-result",ag~generationId),"activate profile"
  store=.AbilityResultStore~new(30,10)

  s1r=ar~acquire("prod","client-result"); call ok s1r,"session 1"; s1=s1r~value
  raw1=.directory~new; raw1["evidence"] = .StoreEvidence~new(11)
  c1=store~create("query",s1,"query",raw1); call ok c1,"create query"; q=c1~value

  s2r=ar~acquire("prod","client-result"); call ok s2r,"session 2"; s2=s2r~value
  raw2=.directory~new; raw2["evidence"] = .StoreEvidence~new(22)
  c2=store~create("evaluation",s2,"evaluate",raw2); call ok c2,"create evaluation"; e=c2~value

  qev=q~evidenceIds~at(1); eev=e~evidenceIds~at(1)
  call neq qev,eev,"evidence ids globally distinct"
  call yes left(qev,q~resultId~length)==q~resultId,"query evidence scoped by result"
  call yes left(eev,e~resultId~length)==e~resultId,"evaluation evidence scoped by result"
  hidden=store~getResult("other-client",q~resultId,"query"); call no hidden~ok,"cross-client result hidden"
  call eq 2,ag~leaseCount,"results retain two sessions"
  call ok store~deleteResult("client-result",q~resultId),"delete query"
  call eq 1,ag~leaseCount,"delete query releases one session"
  missing=store~getEvidence("client-result",qev); call no missing~ok,"query evidence removed with result"
  call ok store~deleteResult("client-result",e~resultId),"delete evaluation"
  call eq 0,ag~leaseCount,"delete evaluation releases final session"
  say "  query_id="||q~resultId
  say "  evaluation_id="||e~resultId
  say "  query_evidence="||qev
  say "  evaluation_evidence="||eev
  say "ABILITY RESULT STORE V0.1: OK"
  return

stage:
  procedure
  use arg kernel,verifier,path
  s=.RuntimeSourceLoader~readFile(path); call ok s,"read fixture"
  aid="result:http:data:1"; call ok verifier~pin(aid,s~value),"pin"
  a=.RuntimeArtifact~new("http.data","CAPABILITY","1.0.0",aid,"HttpDataCapability",s~value)
  r=kernel~stage("prod",a); call ok r,"stage"; return r~value
ok:
  procedure
  use arg r,l; if \r~ok then do; say "FAILED:" l r~code r~detail; exit 91; end; return
eq:
  procedure
  use arg x,y,l; if x\==y then do; say "FAILED:" l "expected=" x "actual=" y; exit 92; end; return
neq:
  procedure
  use arg x,y,l; if x==y then do; say "FAILED:" l "unexpected=" x; exit 93; end; return
yes:
  procedure
  use arg v,l; if \v then do; say "FAILED:" l; exit 94; end; return
no:
  procedure
  use arg v,l; if v then do; say "FAILED:" l; exit 95; end; return

::class StoreEvidence public
::attribute value get
::method init
  expose value
  use arg valueArg
  value=valueArg
::method isEvidenceBearing
  return .true
::method sourcePath
  expose value
  return "/store/"||value
::method sourceDocument
  return .nil

::requires "AbilityResultStore.cls"
