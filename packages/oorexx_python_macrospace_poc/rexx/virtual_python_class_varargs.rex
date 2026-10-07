/* v0.31.2: arbitrary positional scalar arguments on class construction,
 * instance dispatch and class dispatch, using the shared length-framed codec. */
use strict arg operation = "RUN"
if operation \== "RUN" then raise syntax 93.900 array ("unknown operation", operation)

cls = .AlchemyPythonClass~loadCls("virtual_class_demo", "VirtualCounter")
o = cls~new("counter", 4, "alpha", "x:y", "semi;colon")
if o~describe \== "counter:4:[alpha,x:y,semi;colon]" then raise syntax 93.900 array ("vararg construction failed", o~describe)
if o~combine("a", 2, "c:d", "", 5) \== "a|2|c:d||5" then raise syntax 93.900 array ("instance vararg dispatch failed")
if cls~class_combine("p", 7, "q:r", "", 9) \== "p|7|q:r||9" then raise syntax 93.900 array ("class vararg dispatch failed")
return "VIRTUAL-PYTHON-CLASS-VARARGS-PASS"

::requires "animals.cls"
