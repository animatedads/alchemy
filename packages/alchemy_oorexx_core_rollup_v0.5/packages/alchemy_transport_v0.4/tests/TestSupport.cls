::class AlchemyTestSupport public
::method tempDir class
  use strict arg prefix = "alchemy-t"
  path = SysTempFileName("/tmp/" || prefix || "-??????")
  if path = "" then raise syntax 88.900 array("temp path failed")
  if SysMkDir(path) \= 0 then raise syntax 88.900 array("temp mkdir failed: " || path)
  return path

::method write class
  use strict arg path, data
  s = .stream~new(path)
  s~open("write replace")
  s~charout(data)
  s~close

::method read class
  use strict arg path
  s = .stream~new(path)
  s~open("read")
  data = s~charin(1, s~chars)
  s~close
  return data

::method mkdir class
  use strict arg path
  rc = SysMkDir(path)
  if rc \= 0 then raise syntax 88.900 array("mkdir failed: " || path)

::method sh class
  use strict arg command
  address system command
  return rc

::method remove class
  use strict arg path
  address system "rm -rf -- " || .AlchemyShell~quote(path)

::method assertEq class
  use strict arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array("FAIL " || label || " expected=" || expected || " actual=" || actual)

::method assertTrue class
  use strict arg condition, label
  if \condition then raise syntax 88.900 array("FAIL " || label)

::method assertRaises class
  use strict arg target, message, label
  raised = .false
  signal on syntax name gotSyntax
  target~send(message)
  signal off syntax
  say "FAIL" label "expected exception"
  exit 1
gotSyntax:
  signal off syntax
  return .true

::requires "AlchemyTransport.cls"
