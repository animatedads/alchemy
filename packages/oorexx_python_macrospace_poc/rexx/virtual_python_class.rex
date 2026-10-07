/* v0.31: load and operate a Python class through the Rexx class surface. */
use strict arg operation = "RUN"
if operation \== "RUN" then raise syntax 93.900 array ("unknown operation", operation)

cls = .AlchemyPythonClass~loadCls("virtual_class_demo", "VirtualCounter")
if cls~family \== "PYTHON-VIRTUAL-CLASS" then raise syntax 93.900 array ("class dispatch failed")
o = cls~new("counter", 4)
if o~describe \== "counter:4" then raise syntax 93.900 array ("construction failed")
if o~bump(3) \== "7" then raise syntax 93.900 array ("instance dispatch failed")
if \ o~isInstanceOfPython(cls) then raise syntax 93.900 array ("Python type authority failed")
return "VIRTUAL-PYTHON-CLASS-PASS"

::requires "animals.cls"
