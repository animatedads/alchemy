say "REXX INTROSPECTOR TEST START"
svc = .SemanticSourceRexxIntrospector~new
child = .context~package~findClass("Child")
info = svc~inspectClass(child)

call assert info["class_id"] = "CHILD", "class id"
call assert info["parents"]~items >= 1, "parent count"
call assert info["parents"][1]["class_id"] = "PARENT", "immediate parent"
call assert findRelation(info["instance_methods"], "BAR", "DECLARED", "CHILD", 1), "declared instance method"
call assert findRelation(info["instance_methods"], "FOO", "INHERITED", "PARENT", 1), "inherited instance method"
call assert findRelation(info["instance_methods"], "SAME", "OVERRIDES", "CHILD", 1), "instance override"
call assert findRelation(info["instance_methods"], "SAME", "SHADOWED", "PARENT", 0), "shadowed parent method"
call assert findRelation(info["class_methods"], "CBAR", "DECLARED", "CHILD", 1), "declared class method"
call assert findRelation(info["class_methods"], "CFOO", "INHERITED", "PARENT", 1), "inherited class method"
call assert findRelation(info["class_methods"], "CSAME", "OVERRIDES", "CHILD", 1), "class override"

pkg = svc~inspectPackage(.context~package)
call assert pkg["runtime"] = "ooRexx", "package runtime"
call assert pkg["classes"]~items >= 2, "package classes"

say "REXX INTROSPECTOR TEST: PASS"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

findRelation: procedure
  use arg rows, methodName, relationKind, originClassId, effective
  do row over rows
    if row["method_name"] = methodName & row["relation_kind"] = relationKind & row["origin_class_id"] = originClassId & row["effective"] = effective then return 1
  end
  return 0

::class Parent public
::method init
  raise syntax 88.900 array("Parent must not be instantiated by introspection test")
::method foo
  return "parent foo"
::method same
  return "parent same"
::method cfoo class
  return "parent cfoo"
::method csame class
  return "parent csame"

::class Child public subclass Parent
::method init
  raise syntax 88.900 array("Child must not be instantiated by introspection test")
::method bar
  return "child bar"
::method same
  return "child same"
::method cbar class
  return "child cbar"
::method csame class
  return "child csame"

::requires "NoSQLServer.cls"
::requires "../src/SemanticSourceRexxIntrospector.cls"
