::class PublisherTestSupport public
::method tempDir class
  p=SysTempFileName("/tmp/alchemy-pub-??????"); if p="" | SysMkDir(p)<>0 then raise syntax 88.900 array("temp failed"); return p
::method mkdir class
  use strict arg p
  address system "mkdir -p -- " || .AlchemyShell~quote(p); if rc<>0 then raise syntax 88.900 array("mkdir failed")
::method write class
  use strict arg p,d
  s=.stream~new(p)~~open("write replace"); s~charout(d); s~close
::method remove class
  use strict arg p
  address system "rm -rf -- " || .AlchemyShell~quote(p)
::method eq class
  use strict arg x,y,l
  if x\==y then raise syntax 88.900 array("FAIL " || l || " expected=" || x || " actual=" || y)
::method ok class
  use strict arg x,l
  if \x then raise syntax 88.900 array("FAIL " || l)
::requires "AlchemyTransport.cls"
