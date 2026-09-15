o = .Inspectable~new
bridge = .AlchemyInspectorBridge~new(.false)
d = bridge~inspectObject(o)
call assertEq "alchemy.oorexx.inspector-clouseau.snapshot.v1", d["schema"], "Clouseau schema"
call assertTrue d["objects"]~items > 0, "object graph present"
call assertTrue d["inheritance_maps"] \== .nil, "inheritance evidence present"
say "PASS test_inspector_bridge"
exit 0

assertTrue: procedure
 use arg x,msg
 if x \== .true then raise syntax 88.900 array("assertTrue failed: "||msg)
 return
assertEq: procedure
 use arg e,a,msg
 if e \== a then raise syntax 88.900 array("assertEq failed: "||msg||" expected="||e||" actual="||a)
 return

::class Inspectable subclass AlchemyObject public
::method init
 expose value
 value = "hello"
 self~initAlchemy
 self~registerStateVariable("value", "CUSTOMER", "test value")
::method hello public
 return "world"

::requires "AlchemyObjects.cls"
