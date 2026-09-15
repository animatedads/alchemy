::class OrchestratorTestSupport public
::method tempDir class
  use strict arg prefix="alchemy-orch"
  p=SysTempFileName("/tmp/" || prefix || "-??????")
  if p="" | SysMkDir(p)<>0 then raise syntax 88.900 array("temp dir failed")
  return p
::method mkdir class
  use strict arg p
  address system "mkdir -p -- " || .AlchemyShell~quote(p)
  if rc<>0 then raise syntax 88.900 array("mkdir failed: " || p)
::method write class
  use strict arg p,d
  slash=p~lastPos("/")
  if slash>1 then self~mkdir(p~left(slash-1))
  s=.stream~new(p)~~open("write replace"); s~charout(d); s~close
::method remove class
  use strict arg p
  address system "rm -rf -- " || .AlchemyShell~quote(p)
::method eq class
  use strict arg expected,actual,label
  if expected\==actual then raise syntax 88.900 array("FAIL " || label || " expected=" || expected || " actual=" || actual)
::method true class
  use strict arg condition,label
  if \condition then raise syntax 88.900 array("FAIL " || label)
::method initRepo class
  use strict arg base
  r=.AlchemyCommandRunner~new
  bare=base || "/remote.git"; repo=base || "/repo"
  self~mkdir(bare)
  r~require(.array~of("git","init","-q","--bare",bare),base)
  r~require(.array~of("git","clone","-q",bare,repo),base)
  r~require(.array~of("git","checkout","-q","-b","main"),repo)
  r~require(.array~of("git","config","user.email","test@example.invalid"),repo)
  r~require(.array~of("git","config","user.name","Orchestrator Test"),repo)
  return .array~of(r,bare,repo)
::requires "AlchemyTransport.cls"
