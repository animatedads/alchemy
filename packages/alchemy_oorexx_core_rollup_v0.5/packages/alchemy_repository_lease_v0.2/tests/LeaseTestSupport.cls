::class LeaseTestSupport public
::method tempDir class
  use strict arg prefix="alchemy-lease-test"
  p=SysTempFileName("/tmp/" || prefix || "-??????")
  if p="" | SysMkDir(p)<>0 then raise syntax 88.900 array("temp dir failed")
  return p
::method write class
  use strict arg path,data
  s=.stream~new(path); s~open("write replace"); s~charout(data); s~close
::method read class
  use strict arg path
  s=.stream~new(path); s~open("read"); d=s~charin(1,s~chars); s~close; return d
::method sh class
  use strict arg cmd
  address system cmd
  return rc
::method assertTrue class
  use strict arg condition,label
  if \condition then raise syntax 88.900 array("FAIL " || label)
::method assertEq class
  use strict arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("FAIL " || label || " expected=" || expected || " actual=" || actual)
::method remove class
  use strict arg p
  address system "rm -rf -- " || .AlchemyRepositoryLeaseShell~quote(p)
::requires "AlchemyRepositoryLease.cls"
