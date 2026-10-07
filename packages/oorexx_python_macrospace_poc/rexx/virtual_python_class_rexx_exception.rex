call RxFuncAdd 'SysLoadFuncs', 'rexxutil', 'SysLoadFuncs'
call SysLoadFuncs

probeClass = .AlchemyPythonClass~loadCls("virtual_class_demo", "RexxExceptionProbe")
peer = .RexxExceptionPeer~new
probe = probeClass~new(peer)
answer = probe~inspect_failure
if answer~pos("RexxError|") \== 1 then raise syntax 93.900 array ("structured Rexx exception type missing", answer)
if answer~pos("|SYNTAX|") == 0 then raise syntax 93.900 array ("structured Rexx condition name missing", answer)
say "VIRTUAL-PYTHON-CLASS-REXX-EXCEPTION-PASS"
exit 0

::class RexxExceptionPeer
::method explode
  raise syntax 93.900 array ("python-visible Rexx failure")

::requires "animals.cls"
