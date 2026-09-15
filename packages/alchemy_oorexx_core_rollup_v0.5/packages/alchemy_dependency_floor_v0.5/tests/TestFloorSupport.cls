::class FloorTestSupport public
::method tempDir class
  use strict arg prefix = "alchemy-floor-test"
  path = SysTempFileName("/tmp/" || prefix || "-??????")
  if path = "" | SysMkDir(path) \= 0 then raise syntax 88.900 array("temp dir failed")
  return path

::method mkdir class
  use strict arg path
  address system "mkdir -p -- " || .AlchemyShell~quote(path)
  if rc \= 0 then raise syntax 88.900 array("mkdir failed")

::method write class
  use strict arg path, data
  s=.stream~new(path)~~open("write replace")
  s~charout(data)
  s~close

::method remove class
  use strict arg path
  address system "rm -rf -- " || .AlchemyShell~quote(path)

::method assertEq class
  use strict arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array("FAIL " || label || " expected=" || expected || " actual=" || actual)

::method assertTrue class
  use strict arg condition, label
  if \condition then raise syntax 88.900 array("FAIL " || label)

::requires "AlchemyTransport.cls"
