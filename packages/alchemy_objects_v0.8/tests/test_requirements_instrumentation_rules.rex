ring=.CryptoMacKeyRing~new
ring~addKey("req", "00112233445566778899aabbccddeeff")
sealer=.AlchemyMacSealer~new(ring)
authority=.AlchemyCapabilityAuthority~new(ring)
o=.RequirementSubject~new(sealer,authority)

/* Declaration is not execution. */
pub0=o~sealPublicIntrospection~payload
host0=findRequirement(pub0["environment_requirements"],"ENV:HOST-READY")
call assertTrue host0 \== .nil, "public environment declaration present"
call assertEq "UNCHECKED",host0["status"],"declared requirement starts unchecked"
call assertFalse host0["checked"],"unchecked declaration not presented as checked"
call assertFalse host0~hasIndex("checker_method"),"public requirement hides checker implementation name"
call assertTrue findRequirement(pub0["external_requirements"],"EXT:SERVICE:CUSTOMER-DEPENDENCY") == .nil, "customer-only external requirement hidden from public"

checks=o~runRequirementChecks
call assertTrue checks~items >= 5,"core plus subject requirement checks returned"
call assertEq "PASS",findCheck(checks,"ENV:HOST-READY")["status"],"boolean checker pass"
call assertEq "FAIL",findCheck(checks,"EXT:SERVICE:CUSTOMER-DEPENDENCY")["status"],"contract checker fail"
call assertEq "UNCHECKED",findCheck(checks,"ENV:MANUAL-ONLY")["status"],"no checker remains explicitly unchecked"

/* Manual/host-supplied assessments are first-class too. */
manual=o~recordRequirementResult("ENV:MANUAL-ONLY","WAIVED","approved maintenance window")
call assertEq "WAIVED",manual["status"],"manual waiver recorded"

/* Repeat collapse preserves counts and annotates the next distinct event. */
e=.directory~new; e["value"]="same"
r1=o~alchemyInstrument("DEMO.REPEAT",e)
r2=o~alchemyInstrument("DEMO.REPEAT",e)
r3=o~alchemyInstrument("DEMO.REPEAT",e)
call assertTrue r1~hasIndex("sequence"),"first repeated event recorded"
call assertEq "REPEAT_COLLAPSED",r2["reason"],"second event collapsed"
call assertEq "REPEAT_COLLAPSED",r3["reason"],"third event collapsed"
e2=.directory~new; e2["value"]="different"
r4=o~alchemyInstrument("DEMO.REPEAT",e2)
call assertEq 2,r4["suppressed_repeats_before"],"next distinct event carries collapsed repeat count"
off=o~alchemyInstrument("DEMO.OFF","ignored")
call assertEq "DISABLED",off["reason"],"disabled point does not record event"

custCap=authority~issueForSeconds("tenant",o~alchemyObjectId,"SEALEDINTROSPECTION","INTROSPECT:CUSTOMER",60)
cust=o~sealedIntrospection("CUSTOMER",custCap)~payload
dep=findRequirement(cust["external_requirements"],"EXT:SERVICE:CUSTOMER-DEPENDENCY")
call assertTrue dep \== .nil,"customer requirement disclosed to customer"
call assertEq "FAIL",dep["status"],"customer sees latest requirement status"
manualCust=findRequirement(cust["environment_requirements"],"ENV:MANUAL-ONLY")
call assertEq "WAIVED",manualCust["status"],"customer sees explicit waiver status"
call assertTrue findPoint(cust["instrumentation_points"],"DEMO.REPEAT") \== .nil,"customer sees customer instrumentation point"
call assertTrue findPoint(cust["instrumentation_points"],"DEMO.OFF") == .nil,"customer cannot see internal disabled point"

intCap=authority~issueForSeconds("ops",o~alchemyObjectId,"SEALEDINTROSPECTION","INTROSPECT:INTERNAL",60)
internal=o~sealedIntrospection("INTERNAL",intCap)~payload
call assertTrue internal~hasIndex("requirement_check_history"),"internal snapshot carries requirement history"
supp=findPoint(internal["instrumentation_suppression"],"DEMO.REPEAT")
call assertTrue supp \== .nil,"internal suppression summary exists"
call assertEq 2,supp["suppressed_total"],"suppression total preserved"
offSupp=findPoint(internal["instrumentation_suppression"],"DEMO.OFF")
call assertEq 1,offSupp["disabled_drops"],"disabled-drop count preserved"

say "PASS test_requirements_instrumentation_rules"
exit 0

findRequirement: procedure
  use strict arg records,id
  do rec over records
    if rec["requirement_id"] = id then return rec
  end
  return .nil
findCheck: procedure
  use strict arg records,id
  do rec over records
    if rec["requirement_id"] = id then return rec
  end
  return .nil
findPoint: procedure
  use strict arg records,name
  do rec over records
    if rec["point"] = name | rec["name"] = name then return rec
  end
  return .nil
assertTrue: procedure
  use strict arg actual,message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed: " || message)
  return
assertFalse: procedure
  use strict arg actual,message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed: " || message)
  return
assertEq: procedure
  use strict arg expected,actual,message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

::class RequirementSubject subclass AlchemyObject
::method init
  use strict arg sealer,authority
  forward class (super) array (.nil,sealer,authority) continue
  self~registerEnvironmentRequirement("HOST-READY","host runtime probe",.true,"CHECKHOST","PUBLIC")
  self~registerEnvironmentRequirement("MANUAL-ONLY","operator attestation",.true,"","CUSTOMER")
  self~registerExternalRequirement("service","customer-dependency","1",.true,"CHECKDEPENDENCY","CUSTOMER")
  self~registerInstrumentationPoint("DEMO.REPEAT","repeat collapse acceptance point",.true,"COLLAPSE","CUSTOMER")
  self~registerInstrumentationPoint("DEMO.OFF","disabled acceptance point",.false,"ALL","INTERNAL")
::method checkHost
  return .true
::method checkDependency
  return .AlchemyContractCheckResult~new(.false,"DEPENDENCY_DOWN","simulated dependency unavailable")

::requires "AlchemyObjects.cls"
