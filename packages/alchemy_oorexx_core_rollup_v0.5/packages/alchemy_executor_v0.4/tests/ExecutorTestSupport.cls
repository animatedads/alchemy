::class ExecutorTestSupport public
::method tempDir class
  use strict arg prefix="alchemy-exec"
  p=SysTempFileName("/tmp/" || prefix || "-??????"); if p="" | SysMkDir(p)<>0 then raise syntax 88.900 array("temp dir failed"); return p
::method mkdir class
  use strict arg p
  address system "mkdir -p -- " || .AlchemyShell~quote(p); if rc<>0 then raise syntax 88.900 array("mkdir failed")
::method write class
  use strict arg p,d
  s=.stream~new(p)~~open("write replace"); s~charout(d); s~close
::method remove class
  use strict arg p
  address system "rm -rf -- " || .AlchemyShell~quote(p)
::method assertEq class
  use strict arg x,y,l
  if x\==y then raise syntax 88.900 array("FAIL " || l || " expected=" || x || " actual=" || y)
::method assertTrue class
  use strict arg x,l
  if \x then raise syntax 88.900 array("FAIL " || l)
::requires "AlchemyTransport.cls"
