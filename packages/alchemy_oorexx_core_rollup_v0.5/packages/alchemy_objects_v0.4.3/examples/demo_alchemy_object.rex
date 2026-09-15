ring = .CryptoMacKeyRing~new
ring~addKey("demo-service", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)

obj = .DemoServiceObject~new(sealer, authority)
say obj~serializedPublicSnapshot

cap = authority~issue("demo-customer", obj~alchemyObjectId, -
                      "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
say obj~serializedSnapshot("CUSTOMER", cap)
exit 0

::class DemoServiceObject subclass AlchemyObject public
::method init
  expose customerName serviceSecret
  use strict arg sealer, authority
  customerName = "Example Ltd"
  serviceSecret = "not customer-visible"
  meta = .directory~new
  meta["purpose"] = "Demonstrate inherited Alchemy object surfaces"
  meta["package_version"] = "demo-0.1"
  self~initAlchemy(meta, sealer, authority)
  self~registerStateVariable("customerName", "CUSTOMER", "tenant display name")
  self~registerStateVariable("serviceSecret", "SECRET", "service-only secret")
  self~registerMethodContract("HELLO", "return greeting", .array~new, "STRING", .false)
  self~registerComplianceCheck("DEMO-HOUSE", "demo calculated score", 10, 10, "CALCULATEHOUSE")

::method hello public
  expose customerName
  return "hello " || customerName

::method calculateHouse public
  return 9

::requires "AlchemyObjects.cls"
