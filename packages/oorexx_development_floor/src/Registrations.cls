/* Registrations.cls
   Durable registration objects for Development Floor bots, execution providers,
   provider accounts, resource providers and deployment providers.

   Logical bot/specialist identity is deliberately separate from the model or
   execution provider selected for a particular assignment.
*/

::class DFBotProfile public
::method init
  expose id role purpose specialistId status capabilities constraints metadata
  use strict arg id, role, purpose="", specialistId=""
  if id~strip = "" then raise syntax 93.900 array("Bot id must not be empty")
  self~id = id~strip
  self~role = translate(role~strip)
  self~purpose = purpose
  self~specialistId = specialistId
  status = "REGISTERED"
  capabilities = .Array~new
  constraints = .Directory~new
  metadata = .Directory~new
::attribute id
::attribute role
::attribute purpose
::attribute specialistId
::attribute status
::attribute capabilities get
::attribute constraints get
::attribute metadata get
::method addCapability
  expose capabilities
  use strict arg capability
  if capability~strip = "" then return self
  if \self~hasCapability(capability) then capabilities~append(translate(capability~strip))
  return self
::method hasCapability
  expose capabilities
  use strict arg capability
  wanted = translate(capability~strip)
  do item over capabilities
    if item = wanted then return .true
  end
  return .false
::method setConstraint
  expose constraints
  use strict arg name, value
  constraints[translate(name)] = value
  return self
::method constraint
  expose constraints
  use strict arg name
  return constraints~at(translate(name))
::method setMetadata
  expose metadata
  use strict arg name, value
  metadata[name] = value
  return self

::class DFBotRegistry public
::method init
  expose entries
  entries = .Directory~new
::method register
  expose entries
  use strict arg profile
  key = translate(profile~id)
  if entries~at(key) <> .nil then raise syntax 93.900 array("Duplicate bot registration", profile~id)
  entries[key] = profile
  return profile
::method at
  expose entries
  use strict arg id
  return entries~at(translate(id))
::method all
  expose entries
  return entries~allItems
::method withCapability
  expose entries
  use strict arg capability
  answer = .Array~new
  do profile over entries~allItems
    if profile~hasCapability(capability) then answer~append(profile)
  end
  return answer


::class DFControlPlaneRegistration public
::method init
  expose id api status kinds metadata
  use strict arg id, api
  if id~strip = "" then raise syntax 93.900 array("Control plane id must not be empty")
  if api~strip = "" then raise syntax 93.900 array("Control plane API must not be empty")
  self~id = id~strip
  self~api = api~strip
  status = "REGISTERED"
  kinds = .Array~new
  metadata = .Directory~new
::attribute id
::attribute api
::attribute status
::attribute kinds get
::attribute metadata get
::method addKind
  expose kinds
  use strict arg kind
  wanted = translate(kind~strip)
  if wanted = "" then return self
  if \self~hasKind(wanted) then kinds~append(wanted)
  return self
::method hasKind
  expose kinds
  use strict arg kind
  wanted = translate(kind~strip)
  do item over kinds
    if item = wanted then return .true
  end
  return .false
::method setMetadata
  expose metadata
  use strict arg name, value
  metadata[name] = value
  return self

::class DFControlPlaneRegistry public
::method init
  expose entries
  entries = .Directory~new
::method register
  expose entries
  use strict arg controlPlane
  key = translate(controlPlane~id)
  if entries~at(key) <> .nil then raise syntax 93.900 array("Duplicate control-plane registration", controlPlane~id)
  entries[key] = controlPlane
  return controlPlane
::method at
  expose entries
  use strict arg id
  return entries~at(translate(id))
::method all
  expose entries
  return entries~allItems
::method forKind
  expose entries
  use strict arg kind
  answer = .Array~new
  do controlPlane over entries~allItems
    if controlPlane~hasKind(kind) then answer~append(controlPlane)
  end
  return answer

::class DFProviderAccountRegistration public
::method init
  expose id provider selector expectedIdentity fundingSource status metadata
  use strict arg id, provider, selector="", expectedIdentity="", fundingSource=""
  if id~strip = "" then raise syntax 93.900 array("Provider account id must not be empty")
  self~id = id~strip
  self~provider = translate(provider~strip)
  self~selector = selector
  self~expectedIdentity = expectedIdentity
  self~fundingSource = fundingSource
  status = "REGISTERED"
  metadata = .Directory~new
::attribute id
::attribute provider
::attribute selector
::attribute expectedIdentity
::attribute fundingSource
::attribute status
::attribute metadata get
::method setMetadata
  expose metadata
  use strict arg name, value
  metadata[name] = value
  return self

::class DFProviderAccountRegistry public
::method init
  expose entries
  entries = .Directory~new
::method register
  expose entries
  use strict arg account
  key = translate(account~id)
  if entries~at(key) <> .nil then raise syntax 93.900 array("Duplicate provider account registration", account~id)
  entries[key] = account
  return account
::method at
  expose entries
  use strict arg id
  return entries~at(translate(id))
::method all
  expose entries
  return entries~allItems
::method forProvider
  expose entries
  use strict arg provider
  answer = .Array~new
  wanted = translate(provider)
  do account over entries~allItems
    if account~provider = wanted then answer~append(account)
  end
  return answer

::class DFExecutionProviderRegistration public
::method init
  expose id provider modelId transport costModel routingClass providerAccountId status capabilities metadata
  use strict arg id, provider, modelId="", transport="", costModel="", routingClass="NORMAL", providerAccountId=""
  if id~strip = "" then raise syntax 93.900 array("Execution provider id must not be empty")
  self~id = id~strip
  self~provider = translate(provider~strip)
  self~modelId = modelId
  self~transport = translate(transport~strip)
  self~costModel = translate(costModel~strip)
  self~routingClass = translate(routingClass~strip)
  self~providerAccountId = providerAccountId
  status = "REGISTERED"
  capabilities = .Array~new
  metadata = .Directory~new
::attribute id
::attribute provider
::attribute modelId
::attribute transport
::attribute costModel
::attribute routingClass
::attribute providerAccountId
::attribute status
::attribute capabilities get
::attribute metadata get
::method addCapability
  expose capabilities
  use strict arg capability
  wanted = translate(capability~strip)
  do item over capabilities
    if item = wanted then return self
  end
  capabilities~append(wanted)
  return self
::method hasCapability
  expose capabilities
  use strict arg capability
  wanted = translate(capability~strip)
  do item over capabilities
    if item = wanted then return .true
  end
  return .false
::method setMetadata
  expose metadata
  use strict arg name, value
  metadata[name] = value
  return self

::class DFExecutionProviderRegistry public
::method init
  expose entries
  entries = .Directory~new
::method register
  expose entries
  use strict arg provider
  key = translate(provider~id)
  if entries~at(key) <> .nil then raise syntax 93.900 array("Duplicate execution provider registration", provider~id)
  entries[key] = provider
  return provider
::method at
  expose entries
  use strict arg id
  return entries~at(translate(id))
::method all
  expose entries
  return entries~allItems
::method eligible
  expose entries
  use strict arg capability, maximumRoutingClass=""
  answer = .Array~new
  do provider over entries~allItems
    if provider~hasCapability(capability) then do
      if maximumRoutingClass = "" then answer~append(provider)
      else if self~routingRank(provider~routingClass) <= self~routingRank(maximumRoutingClass) then answer~append(provider)
    end
  end
  return answer
::method routingRank private
  use strict arg routingClass
  c = translate(routingClass)
  select
    when c = "LOCAL" then return 10
    when c = "NORMAL" then return 20
    when c = "STRONG" then return 30
    when c = "PREMIUM_ESCALATION" then return 40
    when c = "EXCEPTIONAL_ESCALATION" then return 50
    otherwise return 100
  end

::class DFResourceProviderRegistration public
::method init
  expose id resourceKind authority operationSurface controlPlaneId status metadata
  use strict arg id, resourceKind, authority, operationSurface="", controlPlaneId=""
  if id~strip = "" then raise syntax 93.900 array("Resource provider id must not be empty")
  self~id = id~strip
  self~resourceKind = translate(resourceKind~strip)
  self~authority = authority
  self~operationSurface = operationSurface
  self~controlPlaneId = controlPlaneId
  status = "REGISTERED"
  metadata = .Directory~new
::attribute id
::attribute resourceKind
::attribute authority
::attribute operationSurface
::attribute controlPlaneId
::attribute status
::attribute metadata get
::method setMetadata
  expose metadata
  use strict arg name, value
  metadata[name] = value
  return self

::class DFResourceProviderRegistry public
::method init
  expose entries
  entries = .Directory~new
::method register
  expose entries
  use strict arg provider
  key = translate(provider~id)
  if entries~at(key) <> .nil then raise syntax 93.900 array("Duplicate resource provider registration", provider~id)
  entries[key] = provider
  return provider
::method at
  expose entries
  use strict arg id
  return entries~at(translate(id))
::method all
  expose entries
  return entries~allItems
::method forKind
  expose entries
  use strict arg resourceKind
  answer = .Array~new
  wanted = translate(resourceKind)
  do provider over entries~allItems
    if provider~resourceKind = wanted then answer~append(provider)
  end
  return answer

::class DFDeploymentProviderRegistration public
::method init
  expose id targetKind deploymentMode hostTransport controlPlaneId status metadata
  use strict arg id, targetKind, deploymentMode, hostTransport="", controlPlaneId=""
  if id~strip = "" then raise syntax 93.900 array("Deployment provider id must not be empty")
  self~id = id~strip
  self~targetKind = translate(targetKind~strip)
  self~deploymentMode = translate(deploymentMode~strip)
  self~hostTransport = hostTransport
  self~controlPlaneId = controlPlaneId
  status = "REGISTERED"
  metadata = .Directory~new
::attribute id
::attribute targetKind
::attribute deploymentMode
::attribute hostTransport
::attribute controlPlaneId
::attribute status
::attribute metadata get
::method setMetadata
  expose metadata
  use strict arg name, value
  metadata[name] = value
  return self

::class DFDeploymentProviderRegistry public
::method init
  expose entries
  entries = .Directory~new
::method register
  expose entries
  use strict arg provider
  key = translate(provider~id)
  if entries~at(key) <> .nil then raise syntax 93.900 array("Duplicate deployment provider registration", provider~id)
  entries[key] = provider
  return provider
::method at
  expose entries
  use strict arg id
  return entries~at(translate(id))
::method all
  expose entries
  return entries~allItems
::method forTargetKind
  expose entries
  use strict arg targetKind
  answer = .Array~new
  wanted = translate(targetKind)
  do provider over entries~allItems
    if provider~targetKind = wanted then answer~append(provider)
  end
  return answer


::class DFApplianceProfileRegistration public
::method init
  expose id targetKind cryptoApi cryptoProvider foreignRuntime nativeProvider privateKeyCapability status capabilities metadata
  use strict arg id, targetKind, cryptoApi="", cryptoProvider="", foreignRuntime="", nativeProvider="", privateKeyCapability=.false
  if id~strip = "" then raise syntax 93.900 array("Appliance profile id must not be empty")
  self~id = id~strip
  self~targetKind = translate(targetKind~strip)
  self~cryptoApi = cryptoApi
  self~cryptoProvider = cryptoProvider
  self~foreignRuntime = foreignRuntime
  self~nativeProvider = nativeProvider
  self~privateKeyCapability = privateKeyCapability
  status = "REGISTERED"
  capabilities = .Array~new
  metadata = .Directory~new
::attribute id
::attribute targetKind
::attribute cryptoApi
::attribute cryptoProvider
::attribute foreignRuntime
::attribute nativeProvider
::attribute privateKeyCapability
::attribute status
::attribute capabilities get
::attribute metadata get
::method addCapability
  expose capabilities
  use strict arg capability
  wanted = capability~strip
  if wanted = "" then return self
  do item over capabilities
    if item = wanted then return self
  end
  capabilities~append(wanted)
  return self
::method hasCapability
  expose capabilities
  use strict arg capability
  wanted = capability~strip
  do item over capabilities
    if item = wanted then return .true
  end
  return .false
::method setMetadata
  expose metadata
  use strict arg name, value
  metadata[name] = value
  return self

::class DFApplianceProfileRegistry public
::method init
  expose entries
  entries = .Directory~new
::method register
  expose entries
  use strict arg profile
  key = translate(profile~id)
  if entries~at(key) <> .nil then raise syntax 93.900 array("Duplicate appliance profile registration", profile~id)
  entries[key] = profile
  return profile
::method at
  expose entries
  use strict arg id
  return entries~at(translate(id))
::method all
  expose entries
  return entries~allItems
::method forTargetKind
  expose entries
  use strict arg targetKind
  answer = .Array~new
  wanted = translate(targetKind)
  do profile over entries~allItems
    if profile~targetKind = wanted then answer~append(profile)
  end
  return answer
::method qualifiedDefault
  expose entries
  use strict arg targetKind
  wanted = translate(targetKind)
  do profile over entries~allItems
    if profile~targetKind = wanted then do
      if profile~status = "QUALIFIED_DEFAULT" then return profile
    end
  end
  return .nil

::class DFRexxOSActivationContract public
::method states class
  return .Array~of("STAGED", "RECONSTRUCTED", "BOUND", "ACTIVE")
::method nextState class
  use strict arg currentState
  state = translate(currentState~strip)
  states = self~states
  do i = 1 to states~items - 1
    if states[i] = state then return states[i + 1]
  end
  return .nil
::method canClaimActive class
  use strict arg currentState
  return translate(currentState~strip) = "ACTIVE"

::class DFHostRegistration public
::method init
  expose id provider providerAccountId lifecycle allocationStatus capabilities metadata
  use strict arg id, provider, providerAccountId="", lifecycle="ACTIVE", allocationStatus="UNKNOWN"
  if id~strip = "" then raise syntax 93.900 array("Host registration id must not be empty")
  self~id = id~strip
  self~provider = translate(provider~strip)
  self~providerAccountId = providerAccountId
  self~lifecycle = translate(lifecycle~strip)
  self~allocationStatus = translate(allocationStatus~strip)
  capabilities = .Directory~new
  metadata = .Directory~new
::attribute id
::attribute provider
::attribute providerAccountId
::attribute lifecycle
::attribute allocationStatus
::attribute capabilities get
::attribute metadata get
::method setCapability
  expose capabilities
  use strict arg name, value
  capabilities[translate(name)] = value
  return self
::method capability
  expose capabilities
  use strict arg name
  return capabilities~at(translate(name))
::method setMetadata
  expose metadata
  use strict arg name, value
  metadata[name] = value
  return self
::method allocatable
  if self~allocationStatus <> "AVAILABLE" then return .false
  return self~lifecycle = "ACTIVE"
::method qualificationEligible
  expose metadata
  if self~lifecycle <> "ACTIVE" then return .false
  allowed = metadata~at("qualification_override_allowed")
  if allowed == .nil then return .false
  if allowed = 1 then return .true
  if translate(allowed~string) = "TRUE" then return .true
  return .false

::class DFHostRegistry public
::method init
  expose entries
  entries = .Directory~new
::method register
  expose entries
  use strict arg host
  key = translate(host~id)
  if entries~at(key) <> .nil then raise syntax 93.900 array("Duplicate host registration", host~id)
  entries[key] = host
  return host
::method at
  expose entries
  use strict arg id
  return entries~at(translate(id))
::method all
  expose entries
  return entries~allItems
::method allocatable
  expose entries
  answer = .Array~new
  do host over entries~allItems
    if host~allocatable then answer~append(host)
  end
  return answer
::method qualificationTarget
  expose entries
  use strict arg id
  host = entries~at(translate(id))
  if host == .nil then return .nil
  if \host~qualificationEligible then return .nil
  return host

::class DFTestDeploymentContract public
::method phases class
  answer = .Array~new
  answer~append("REQUEST_RESOURCE_SET")
  answer~append("ALLOCATE_HOST")
  answer~append("RESERVE_WLU")
  answer~append("ASSIGN_QEMU")
  answer~append("ACQUIRE_NETWORK_LEASE")
  answer~append("DEPLOY_OR_MATERIALISE")
  answer~append("RUN_TEST")
  answer~append("COLLECT_EVIDENCE")
  answer~append("CLEAR_DOWN")
  answer~append("REVOKE_NETWORK_LEASE")
  answer~append("RELEASE_WLU")
  answer~append("RELEASE_HOST")
  return answer
::method networkProfiles class
  return .Array~of("NONE", "HOST_LOCAL", "CROSS_GUEST_LOCAL_HOST", "CROSS_HOST")
::method topologies class
  return .Array~of("SINGLE", "PAIRED_RTO", "FAILOVER", "FORENSIC_FAILOVER")

::class DFRegistrationCatalog public
::method init
  expose bots controlPlanes providerAccounts executionProviders resourceProviders deploymentProviders applianceProfiles hosts
  bots = .DFBotRegistry~new
  controlPlanes = .DFControlPlaneRegistry~new
  providerAccounts = .DFProviderAccountRegistry~new
  executionProviders = .DFExecutionProviderRegistry~new
  resourceProviders = .DFResourceProviderRegistry~new
  deploymentProviders = .DFDeploymentProviderRegistry~new
  applianceProfiles = .DFApplianceProfileRegistry~new
  hosts = .DFHostRegistry~new
::attribute bots get
::attribute controlPlanes get
::attribute providerAccounts get
::attribute executionProviders get
::attribute resourceProviders get
::attribute deploymentProviders get
::attribute applianceProfiles get
::attribute hosts get
::method fromJsonFile class
  use strict arg path
  if stream(path, "c", "query exists") == "" then raise syntax 93.900 array("Registration file does not exist", path)
  f = .stream~new(path)
  f~open("READ")
  text = f~charIn(, f~chars)
  f~close
  raw = .json~fromJson(text)
  if \raw~isA(.Directory) then raise syntax 93.900 array("Registration root must be a JSON object")
  answer = .DFRegistrationCatalog~new
  answer~loadDirectory(raw)
  return answer
::method loadDirectory
  expose bots controlPlanes providerAccounts executionProviders resourceProviders deploymentProviders applianceProfiles hosts
  use strict arg raw
  schema = raw~at("schema")
  if schema == .nil then raise syntax 93.900 array("Registration schema missing")
  supported = .false
  if schema = "development.floor.registrations/0.1" then supported = .true
  if schema = "development.floor.registrations/0.2" then supported = .true
  if schema = "development.floor.registrations/0.3" then supported = .true
  if schema = "development.floor.registrations/0.4" then supported = .true
  if schema = "development.floor.registrations/0.5" then supported = .true
  if \supported then raise syntax 93.900 array("Unsupported registration schema", schema)

  list = raw~at("bots")
  if list <> .nil then do item over list
    profile = .DFBotProfile~new(item["id"], item["role"], self~valueOr(item,"purpose",""), self~valueOr(item,"specialist_id",""))
    caps = item~at("capabilities")
    if caps <> .nil then do cap over caps; profile~addCapability(cap); end
    cons = item~at("constraints")
    if cons <> .nil then do key over cons; profile~setConstraint(key, cons[key]); end
    profile~status = self~valueOr(item,"status","REGISTERED")
    bots~register(profile)
  end

  list = raw~at("control_planes")
  if list <> .nil then do item over list
    controlPlane = .DFControlPlaneRegistration~new(item["id"], item["api"])
    kinds = item~at("kinds")
    if kinds <> .nil then do kind over kinds; controlPlane~addKind(kind); end
    meta = item~at("metadata")
    if meta <> .nil then do key over meta; controlPlane~setMetadata(key, meta[key]); end
    controlPlane~status = self~valueOr(item,"status","REGISTERED")
    controlPlanes~register(controlPlane)
  end

  list = raw~at("provider_accounts")
  if list <> .nil then do item over list
    account = .DFProviderAccountRegistration~new(item["id"], item["provider"], self~valueOr(item,"selector",""), self~valueOr(item,"expected_identity",""), self~valueOr(item,"funding_source",""))
    meta = item~at("metadata")
    if meta <> .nil then do key over meta; account~setMetadata(key, meta[key]); end
    account~status = self~valueOr(item,"status","REGISTERED")
    providerAccounts~register(account)
  end

  list = raw~at("execution_providers")
  if list <> .nil then do item over list
    provider = .DFExecutionProviderRegistration~new(item["id"], item["provider"], self~valueOr(item,"model_id",""), self~valueOr(item,"transport",""), self~valueOr(item,"cost_model",""), self~valueOr(item,"routing_class","NORMAL"), self~valueOr(item,"provider_account_id",""))
    caps = item~at("capabilities")
    if caps <> .nil then do cap over caps; provider~addCapability(cap); end
    meta = item~at("metadata")
    if meta <> .nil then do key over meta; provider~setMetadata(key, meta[key]); end
    provider~status = self~valueOr(item,"status","REGISTERED")
    executionProviders~register(provider)
  end

  list = raw~at("resource_providers")
  if list <> .nil then do item over list
    provider = .DFResourceProviderRegistration~new(item["id"], item["resource_kind"], item["authority"], self~valueOr(item,"operation_surface",""), self~valueOr(item,"control_plane_id",""))
    meta = item~at("metadata")
    if meta <> .nil then do key over meta; provider~setMetadata(key, meta[key]); end
    provider~status = self~valueOr(item,"status","REGISTERED")
    resourceProviders~register(provider)
  end

  list = raw~at("deployment_providers")
  if list <> .nil then do item over list
    provider = .DFDeploymentProviderRegistration~new(item["id"], item["target_kind"], item["deployment_mode"], self~valueOr(item,"host_transport",""), self~valueOr(item,"control_plane_id",""))
    meta = item~at("metadata")
    if meta <> .nil then do key over meta; provider~setMetadata(key, meta[key]); end
    provider~status = self~valueOr(item,"status","REGISTERED")
    deploymentProviders~register(provider)
  end

  list = raw~at("appliance_profiles")
  if list <> .nil then do item over list
    profile = .DFApplianceProfileRegistration~new(item["id"], item["target_kind"], self~valueOr(item,"crypto_api",""), self~valueOr(item,"crypto_provider",""), self~valueOr(item,"foreign_runtime",""), self~valueOr(item,"native_provider",""), self~valueOr(item,"private_key_capability",.false))
    caps = item~at("capabilities")
    if caps <> .nil then do cap over caps; profile~addCapability(cap); end
    meta = item~at("metadata")
    if meta <> .nil then do key over meta; profile~setMetadata(key, meta[key]); end
    profile~status = self~valueOr(item,"status","REGISTERED")
    applianceProfiles~register(profile)
  end

  list = raw~at("hosts")
  if list <> .nil then do item over list
    host = .DFHostRegistration~new(item["id"], item["provider"], self~valueOr(item,"provider_account_id",""), self~valueOr(item,"lifecycle","ACTIVE"), self~valueOr(item,"allocation_status","UNKNOWN"))
    caps = item~at("capabilities")
    if caps <> .nil then do key over caps; host~setCapability(key, caps[key]); end
    meta = item~at("metadata")
    if meta <> .nil then do key over meta; host~setMetadata(key, meta[key]); end
    hosts~register(host)
  end
  return self
::method valueOr private
  use strict arg directory, key, defaultValue
  value = directory~at(key)
  if value == .nil then return defaultValue
  return value

::requires "json.cls"
