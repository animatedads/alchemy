/* v0.31.1: projected Python class ownership release is idempotent. */
cls = .AlchemyPythonClass~loadCls("virtual_class_demo", "VirtualCounter")
h = cls~foreignHandle
cls~uninit
cls~uninit
return h
::requires "animals.cls"
