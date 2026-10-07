/* v0.31.3: projected Python objects/classes cross as live identities. */
use strict arg operation = "RUN"
if operation \== "RUN" then raise syntax 93.900 array ("unknown operation", operation)

cls = .AlchemyPythonClass~loadCls("virtual_class_demo", "IdentityBox")
a = cls~new("alpha")
b = cls~new("beta")

if a~same(a) \== "True" then raise syntax 93.900 array ("self identity argument failed")
if a~same(b) \== "False" then raise syntax 93.900 array ("distinct identity argument failed")
if a~same_pair(b, b) \== "True" then raise syntax 93.900 array ("repeated identity argument failed")
if a~accepts_type(cls) \== "True" then raise syntax 93.900 array ("class identity argument failed")
if cls~class_same(cls) \== "True" then raise syntax 93.900 array ("class dispatch class argument failed")

returned = a~my_type
if \ returned~isInstanceOf(.AlchemyPythonClass) then raise syntax 93.900 array ("Python type return was not class projection")
if returned~qualifiedName \== cls~qualifiedName then raise syntax 93.900 array ("returned class identity/info mismatch")
if a~isInstanceOfPython(returned) \== 1 then raise syntax 93.900 array ("returned class is not authoritative type")

return "VIRTUAL-PYTHON-CLASS-IDENTITY-ARGS-PASS"
::requires "animals.cls"
