qm = .ObjectQueueManager~new
call assert qm~createQueue("IN", "TEMPORARY", "DEFAULT", 0, "bridge")~ok, "queue create"
provider = .FakeJMSProvider~new
config = .JMSBridgeConfig~new("adoption", "GENERIC", "", "", "remote", "", "", "", "", "IN", "", "bridge", .false)
bridge = .JMSQueueBridgeService~new(qm, provider, config)

adoptionResult = .AlchemyAdoptionVerifier~verify(bridge, "STANDARD")
call assert adoptionResult~ok, "bridge STANDARD adoption"
call assert adoptionResult~warnings~items = 0, "bridge adoption has zero warnings"
contract = .AlchemyAdoptionVerifier~contract
call assert contract["base_version"] = "0.8", "Alchemy Objects v0.8 active"

base = bridge~alchemyBaseState
call assert base["initialized"], "Alchemy base initialized"
call assert base["construction_provenance"]["entrypoint"] = "INIT", "preferred non-virtual INIT provenance"

say "JMS BRIDGE ALCHEMY V0.8 ADOPTION PASS 6"
exit 0

assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return

::requires "AlchemyAdoption.cls"
::requires "JMSQueueBridge.cls"
::requires "FakeJMSProvider.cls"
