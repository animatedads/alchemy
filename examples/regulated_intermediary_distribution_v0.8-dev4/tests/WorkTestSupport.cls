::class RIDAlwaysValidSignatureVerifier public
::method verify
  return .true

::class RIDManualTimeSource subclass QueueTimeSource public
::method init
  expose tick
  use arg initialTick = 1000000
  tick = initialTick + 0
::method nowTick
  expose tick
  numeric digits 30
  return tick
::method addSeconds
  use arg baseTick, seconds
  numeric digits 30
  return baseTick + (seconds * 1000000)
::method isExpired
  expose tick
  use arg expiryTick
  if expiryTick == .nil | expiryTick = "" | expiryTick = 0 then return .false
  numeric digits 30
  return tick >= expiryTick
::method secondsUntil
  expose tick
  use arg expiryTick
  if expiryTick == .nil | expiryTick = "" | expiryTick = 0 then return 0
  numeric digits 30
  remaining = expiryTick - tick
  if remaining <= 0 then return 0
  return remaining / 1000000
::method advance
  expose tick
  use arg seconds
  numeric digits 30
  tick = tick + (seconds * 1000000)
  return tick

::class RIDWorkIntegrationFixtures public
::method setup class
  use arg family = "MORTGAGE", providerEntity = "FEDERATIONBANK_PLC", providerSystem = "FEDERATION_MORTGAGE", productId = "HOME-1", semanticIdentity = "HOME-1|2026.08|A", clock = .nil, workPolicy = .nil
  root = "/tmp/rid_work_" || .DateTime~new~microseconds
  if clock == .nil then manager = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, "RID_ADMIN")
  else manager = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, "RID_ADMIN", .nil, .nil, "STRICT", clock)
  env = .RIDTestFixtures~environment(family, "ADVISED", providerEntity, providerSystem, productId, "2026.08", semanticIdentity)
  engine = env["ENGINE"]
  c = .RIDTestSupport~ok(engine~openCase("CASE-W", "CUSTOMER:W", "FIRM-1", "REP-1", "PROD-1", "ADVISED", "REP-1", "INTERMEDIARY_REPRESENTATIVE", env["NOW"]))
  p = env["PRODUCT"]
  keys = .RIDSigningKeyRegistry~new
  before = env["NOW"] - .TimeSpan~new(0,0,0,0,60)
  signer = p~providerIdentity~authorityKey
  .RIDTestSupport~ok(keys~register(.RIDSigningKey~new("PROVIDER-WORK-KEY", signer, "ED25519", "test-public-key", "PROVIDER_EVENT", before, .nil, "TEST:KEY")))
  signatures = .RIDDigitalSignatureService~new(keys, .RIDAlwaysValidSignatureVerifier~new)
  bridge = .RIDQueueEventBridge~new(manager, engine, signatures, "RID_ADMIN")
  .RIDTestSupport~ok(bridge~configure)
  if clock == .nil then service = .RIDIntermediaryWorkService~new(manager, bridge~topicFabric, engine, env["CATALOG"], workPolicy, "RID_ADMIN")
  else service = .RIDIntermediaryWorkService~new(manager, bridge~topicFabric, engine, env["CATALOG"], workPolicy, "RID_ADMIN", clock)
  .RIDTestSupport~ok(service~configure)
  d = .directory~new
  d["ROOT"] = root; d["ENV"] = env; d["MANAGER"] = manager; d["ENGINE"] = engine; d["CASE"] = c; d["PRODUCT"] = p
  d["SIGNER"] = signer; d["SIGNATURES"] = signatures; d["BRIDGE"] = bridge; d["SERVICE"] = service
  if clock <> .nil then d["CLOCK"] = clock
  return d
::method providerStatus class
  use arg fx, eventId, sequence, status
  p = fx["PRODUCT"]; env = fx["ENV"]; c = fx["CASE"]
  e = .RIDProviderStatusEvidence~new(eventId, p~providerIdentity~legalEntityId, p~providerIdentity~providerSystem, "PROVIDER:CASE:W", p~productSemanticIdentity, sequence, status, env["NOW"], "PROVIDER:" || eventId)
  return .RIDSignedProviderStatusEvent~new(e, fx["SIGNER"], "PROVIDER-WORK-KEY", "test-signature", env["NOW"], "CHANNEL:" || eventId)
::method driveStatus class
  use arg fx, signed
  .RIDTestSupport~ok(fx["BRIDGE"]~enqueueProviderStatus(fx["CASE"]~caseId, signed))
  .RIDTestSupport~ok(fx["BRIDGE"]~canonicalizeOne)
  return fx["BRIDGE"]~projectOne
::method cleanup class
  use arg fx
  address system "rm -rf " || fx["ROOT"]
  return .true

::requires "RegulatedIntermediaryDistribution.cls"
::requires "RIDDigitalSigning.cls"
::requires "RIDQueueEventBridge.cls"
::requires "RIDIntermediaryService.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"
