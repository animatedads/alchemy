::class SubmissionTestSupport public
::method tempDir class
  use strict arg prefix="alchemy-submit"
  p=SysTempFileName("/tmp/" || prefix || "-??????"); if p="" | SysMkDir(p)<>0 then raise syntax 88.900 array("temp dir failed"); return p
::method mkdir class
  use strict arg p
  address system "mkdir -p -- " || .AlchemyShell~quote(p); if rc<>0 then raise syntax 88.900 array("mkdir failed")
::method write class
  use strict arg p,d
  slash=p~lastPos("/"); if slash>1 then self~mkdir(p~left(slash-1))
  s=.stream~new(p)~~open("write replace"); s~charout(d); s~close
::method remove class
  use strict arg p
  address system "rm -rf -- " || .AlchemyShell~quote(p)
::method eq class
  use strict arg e,a,l
  if e\==a then raise syntax 88.900 array("FAIL " || l || " expected=" || e || " actual=" || a)
::method true class
  use strict arg c,l
  if \c then raise syntax 88.900 array("FAIL " || l)
::requires "AlchemyTransport.cls"
