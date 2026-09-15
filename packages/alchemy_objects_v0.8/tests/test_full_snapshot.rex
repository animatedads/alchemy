ring=.CryptoMacKeyRing~new
ring~addKey("snap", "00112233445566778899aabbccddeeff")
sealer=.AlchemyMacSealer~new(ring)
authority=.AlchemyCapabilityAuthority~new(ring)
o=.FullObject~new(sealer,authority)
bridge=.TinyInspector~new
cap=authority~issue("support",o~alchemyObjectId,"SEALEDINTROSPECTION","INTROSPECT:FULL")
envelope=o~sealedIntrospection("FULL",cap,bridge)
if \sealer~verify(envelope) then raise syntax 88.900 array("full snapshot seal failed")
p=envelope~payload
if \p~hasIndex("state") then raise syntax 88.900 array("full state missing")
if \p~hasIndex("source") then raise syntax 88.900 array("full source missing")
if \p~hasIndex("graph") then raise syntax 88.900 array("full graph missing")
if p["state"]["SECRET"] \== "s3cr3t" then raise syntax 88.900 array("full secret state not captured")
if p["source"]["schema"] \= "alchemy.objects.source-snapshot/0.2" then raise syntax 88.900 array("source snapshot schema mismatch")
if p["source"]["source_scope"] \= "CONCRETE_PACKAGE" then raise syntax 88.900 array("source snapshot scope mismatch")
if p["source"]["package_source"]~items = 0 then raise syntax 88.900 array("concrete package source missing")
if p["source"]["methods"]~items = 0 then raise syntax 88.900 array("concrete class method metadata empty")
if p["source"]["lineage"]~items < 2 then raise syntax 88.900 array("source lineage missing inherited base")
if p["source"]["inherited_source_externalized"] \= .true then raise syntax 88.900 array("inherited source externalization marker missing")
say "PASS test_full_snapshot"
exit 0

::class TinyInspector public
::method inspectObject
  use arg target
  d=.directory~new
  d["schema"]="test.graph/0.1"
  d["target"] = target~alchemyObjectId
  return d

::class FullObject subclass AlchemyObject public
::method init
 expose secret publicValue
 use strict arg sealer, authority
 secret="s3cr3t"; publicValue="hello"
 meta=.directory~new; meta["purpose"]="full snapshot test"
 self~initAlchemy(meta,sealer,authority)
 self~registerStateVariable("secret","SECRET","secret test slot")
 self~registerStateVariable("publicValue","PUBLIC","public test slot")
::method hello public
 return publicValue

::requires "AlchemyObjects.cls"
