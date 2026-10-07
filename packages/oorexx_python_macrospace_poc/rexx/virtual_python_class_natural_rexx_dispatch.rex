call RxFuncAdd 'SysLoadFuncs', 'rexxutil', 'SysLoadFuncs'
call SysLoadFuncs

holderClass = .AlchemyPythonClass~loadCls("virtual_class_demo", "NaturalRexxPeerHolder")
peer = .RexxPeer~new("alpha")
holder = holderClass~new(peer)
if holder~ask \== "REXX-PEER:alpha" then raise syntax 93.900 array ("Python did not operate retained Rexx object", holder~ask)
say "VIRTUAL-PYTHON-CLASS-NATURAL-REXX-DISPATCH-PASS"
exit 0

::class RexxPeer
::method init
  expose name
  use strict arg name
::method describe
  expose name
  return "REXX-PEER:" || name

::requires "animals.cls"
