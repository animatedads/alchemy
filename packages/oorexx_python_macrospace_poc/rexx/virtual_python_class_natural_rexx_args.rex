call RxFuncAdd 'SysLoadFuncs', 'rexxutil', 'SysLoadFuncs'
call SysLoadFuncs

holderClass = .AlchemyPythonClass~loadCls("virtual_class_demo", "NaturalRexxArgsHolder")
peer = .RexxArgPeer~new("root")
holder = holderClass~new(peer)
if holder~combine \== "left|7|" then raise syntax 93.900 array ("natural Rexx args failed", holder~combine)
if holder~child_name \== "REXX-CHILD:root-child" then raise syntax 93.900 array ("Rexx return reprojection failed", holder~child_name)
if holder~same_child \== "True" then raise syntax 93.900 array ("Rexx returned object identity argument failed", holder~same_child)
say "VIRTUAL-PYTHON-CLASS-NATURAL-REXX-ARGS-PASS"
exit 0

::class RexxArgPeer
::method init
  expose name child
  use strict arg name
  child = .RexxChild~new(name || "-child")
::method combine
  use strict arg a, b, c
  return a || "|" || b || "|" || c
::method child
  expose child
  return child
::method same
  expose child
  use strict arg candidate
  return candidate == child

::class RexxChild
::method init
  expose name
  use strict arg name
::method describe
  expose name
  return "REXX-CHILD:" || name

::requires "animals.cls"
