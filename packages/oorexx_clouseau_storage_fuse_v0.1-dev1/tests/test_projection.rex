app=.TestApp~new
inspector=.InspectorClouseau~new
inspector~enableProbes(.true)
inspector~dontFollowPackage("REXX")
inspector~reportVariable("*")
inspector~reportInheritanceMap(.true)
inspector~createInspectionReportOnMethod("TESTCHILD","CHANGECHILD","*","*",.nil,.nil,"out/test-change")
inspector~suppressObjectOutputForPath("root:.environment*")
inspector~attach("app",app)
inspector~attach("child",app~child)
bridge=.ClouseauStorageFuseBridge~new(inspector,"/live/test")
ignore=bridge~refresh
objects=bridge~listVirtual("/live/test/objects")
call assert objects<>.nil,"objects directory exists"
found=.false
foundValue=.false
do oid over objects
  if bridge~readVirtual("/live/test/objects/"||oid||"/class")="TESTCHILD" then do
    found=.true
    attrs=bridge~listVirtual("/live/test/objects/"||oid||"/attributes")
    if attrs<>.nil then do a over attrs
      if translate(a)="CHILDVALUE" then do
        foundValue=.true
        call assert bridge~readVirtual("/live/test/objects/"||oid||"/attributes/"||a||"/value")="alpha","live CHILDVALUE observed"
      end
    end
  end
end
call assert found,"TESTCHILD object projected"
call assert foundValue,"TESTCHILD attributes projected"
origin=bridge~readVirtual("/live/test/classes/TESTCHILD/methods/MIXED/origin_class")
call assert origin="MIXEDCAPABILITY","mixin method origin projected"
kind=bridge~readVirtual("/live/test/classes/TESTCHILD/methods/MIXED/origin_kind")
call assert kind="inherited_mixin_or_secondary_superclass","mixin resolution classified"
app~child~changeChild("beta")
ignore=bridge~refresh
updated=.false
objects=bridge~listVirtual("/live/test/objects")
do oid over objects
  if bridge~readVirtual("/live/test/objects/"||oid||"/class")="TESTCHILD" then do
    attrs=bridge~listVirtual("/live/test/objects/"||oid||"/attributes")
    if attrs<>.nil then do a over attrs
      if translate(a)="CHILDVALUE" then updated=(bridge~readVirtual("/live/test/objects/"||oid||"/attributes/"||a||"/value")="beta")
    end
  end
end
call assert updated,"refresh observes changed live value"
say "PASS Clouseau Storage FUSE projection"
exit 0

assert:
  use arg ok,msg
  if \ok then do; say "FAIL" msg; exit 1; end
  return

::requires "InspectorClouseau.cls"
::requires "ClouseauStorageFuse.cls"

::class Inspectable MIXINCLASS Object
::method __INSPECTOR_CLOUSEAU_INSTALL
  use strict arg probeName,source,scope="OBJECT"
  self~setMethod(probeName,source,scope); return .true
::method __INSPECTOR_CLOUSEAU_UNINSTALL
  use strict arg probeName
  self~unsetMethod(probeName); return .true

::class MixedCapability MIXINCLASS Object
::method mixed
  return "from-mixin"

::class TestBase public inherit Inspectable
::attribute value
::method init
  expose value
  value="alpha"
::method change
  expose value
  use strict arg v
  value=v
  return value

::class TestChild public subclass TestBase inherit MixedCapability
::attribute childValue
::method init
  expose childValue
  self~init:super
  childValue="alpha"
::method changeChild
  expose childValue
  use strict arg v
  childValue=v
  return childValue


::class TestApp public inherit Inspectable
::attribute child
::method init
  expose child
  child=.TestChild~new